
module MyTasks
  class GoogleTasks
    include MyTasks::TasksModule
    include Cache::UserCacheExpiry

    def initialize(uid, starting_date)
      @uid = uid
      @starting_date = starting_date
      @now_time = Time.zone.now
    end

    def fetch_tasks
      self.class.fetch_from_cache(@uid) {
        all_tasks = []
        filtered_tasks = []
        google_proxy = GoogleApps::TasksList.new(user_id: @uid)

        Rails.logger.info "#{self.class.name} Sorting Google tasks into buckets with starting_date #{@starting_date}"
        google_proxy.tasks_list.each do |response_page|
          next unless response_page && response_page.response.status == 200
          response_page.data["items"].each do |entry|
            next if entry["title"].blank?
            formatted_entry = format_google_task_response(entry)
            all_tasks.push formatted_entry
          end
        end
        all_tasks.sort! { |a, b| (a["dueDate"].nil? ? 0 : a["dueDate"]["epoch"]) <=> (b["dueDate"].nil? ? 0 : b["dueDate"]["epoch"]) }
        all_tasks.each do |formatted_entry|
          filtered_tasks.push(formatted_entry)
        end
        filtered_tasks
      }
    end

    def return_response(response)
      formatted_response = {}
      if response && response.response.status == 200
        formatted_response = format_google_task_response response.data
      else
        Rails.logger.info "Errors in proxy response: #{response.inspect}"
      end
      formatted_response
    end

    def update_task(params, task_list_id="@default")
      body = format_google_update_task_request params
      google_proxy = GoogleApps::UpdateTask.new(user_id: @uid)
      Rails.logger.debug "#{self.class.name} update_task, sending to Google (task_list_id, task_id, body):
          {#{task_list_id}, #{params["id"]}, #{body.inspect}}"
      return_response google_proxy.update_task(task_list_id, params["id"], body)
    end

    def insert_task(params, task_list_id="@default")
      body = format_google_insert_task_request params
      google_proxy = GoogleApps::InsertTask.new(user_id: @uid)
      Rails.logger.debug "#{self.class.name} insert_task, sending to Google (task_list_id, body):
            {#{task_list_id}, #{body.inspect}}"
      return_response google_proxy.insert_task(task_list_id, body)
    end

    def clear_completed_tasks(task_list_id="@default")
      google_proxy = GoogleApps::ClearTaskList.new(user_id: @uid)
      Rails.logger.debug "#{self.class.name} clearing task list, sending to Google (task_list_id):
            {#{task_list_id}}"
      result = google_proxy.clear_task_list(task_list_id)
      {tasksCleared: result}
    end

    def delete_task(params, task_list_id="@default")
      google_proxy = GoogleApps::DeleteTask.new(user_id: @uid)
      Rails.logger.debug "#{self.class.name} delete_task, sending to Google (task_list_id, params):
            {#{task_list_id}, #{params.inspect}}"
      response  = google_proxy.delete_task(task_list_id, params[:task_id])
      {task_deleted: response}
    end

    private

    def format_google_insert_task_request(entry)
      formatted_entry = {}
      formatted_entry["title"] = entry["title"]
      if entry["dueDate"] && !entry["dueDate"].blank?
        formatted_entry["due"] = Date.strptime(entry["dueDate"]).in_time_zone.to_datetime
      end
      formatted_entry["notes"] = entry["notes"] if entry["notes"]
      Rails.logger.debug "Formatted body entry for google proxy update_task: #{formatted_entry.inspect}"
      formatted_entry
    end

    def format_google_delete_task_request(entry)
      formatted_entry = {}
      formatted_entry["id"] = entry["id"]
      Rails.logger.debug "Formatted body entry for google proxy delete_task: #{formatted_entry.inspect}"
      formatted_entry
    end

    def format_google_update_task_request(entry)
      validate_google_params entry
      formatted_entry = {"id" => entry["id"]}
      formatted_entry["status"] = "needsAction" if entry["status"] == "needsAction"
      formatted_entry["status"] ||= "completed"
      formatted_entry["title"] = entry["title"] unless entry["title"].blank?
      formatted_entry["notes"] = entry["notes"] unless entry["notes"].nil?
      if entry["dueDate"] && entry["dueDate"]["dateTime"]
        formatted_entry["due"] = Date.strptime(entry["dueDate"]["dateTime"]).in_time_zone.to_datetime
      end
      Rails.logger.debug "Formatted body entry for google proxy update_task: #{formatted_entry.inspect}"
      formatted_entry
    end

    def format_google_task_response(entry)
      formatted_entry = {
        "type" => "task",
        "title" => entry["title"] || "",
        "emitter" => GoogleApps::Proxy::APP_ID,
        "linkUrl" => "https://mail.google.com/tasks/canvas?pli=1",
        "id" => entry["id"],
        "sourceUrl" => entry["selfLink"] || ""
      }

      # Some fields may or may not be present in Google feed
      formatted_entry["notes"] = entry["notes"] if entry["notes"]

      if entry["completed"]
        format_date_into_entry!(convert_date(entry["completed"]), formatted_entry, "completedDate")
      end

      status = "needsAction" if entry["status"] == "needsAction"
      status ||= "completed"
      formatted_entry["status"] = status
      due_date = entry["due"]
      unless due_date.nil?
        # Google task dates have misleading datetime accuracy. There is no way to record a specific due time
        # for tasks (through the UI), thus the reported time+tz is always 00:00:00+0000. Stripping off the false
        # accuracy so the application will apply the proper timezone when needed.
        due_date = Date.parse(due_date.to_s)
        # Tasks are not overdue until the end of the day.
        due_date = due_date.in_time_zone.to_datetime.advance(:hours => 23, :minutes => 59, :seconds => 59)
      end
      formatted_entry["bucket"] = determine_bucket(due_date, formatted_entry, @now_time, @starting_date)

      if formatted_entry["bucket"] == "Unscheduled"
        format_date_into_entry!(convert_date(entry["updated"]), formatted_entry, "updatedDate")
      end

      Rails.logger.debug "#{self.class.name} Putting Google task with dueDate #{formatted_entry["dueDate"]} in #{formatted_entry["bucket"]} bucket: #{formatted_entry}"
      format_date_into_entry!(due_date, formatted_entry, "dueDate")
      Rails.logger.debug "#{self.class.name}: Formatted body response from google proxy - #{formatted_entry.inspect}"
      formatted_entry
    end

    def validate_google_params(params)
      # just need to make sure ID is non-blank, general_params caught the rest.
      google_filters = {"id" => "noop, not a Proc type"}
      validate_params(params, google_filters)
    end
  end
end
