module Canvas
  require 'csv'

  # Generates and imports SIS User and Enrollment CSV dumps into Canvas based on campus SIS information.
  class RefreshAllCampusData < Csv
    include ClassLogger
    attr_accessor :users_csv_filename
    attr_accessor :term_to_memberships_csv_filename

    def initialize(batch_or_incremental)
      super()
      @users_csv_filename = "#{@export_dir}/canvas-#{DateTime.now.strftime('%F')}-users-#{batch_or_incremental}.csv"
      @term_to_memberships_csv_filename = {}
      @batch_mode = (batch_or_incremental == 'batch')
      term_ids = Canvas::Proxy.current_sis_term_ids
      term_ids.each do |term_id|
        # Prevent collisions between the SIS_ID code and the filesystem.
        sanitized_term_id = term_id.gsub(/[^a-z0-9\-.]+/i, '_')
        csv_filename = "#{@export_dir}/canvas-#{DateTime.now.strftime('%F')}-#{sanitized_term_id}-enrollments-#{batch_or_incremental}.csv"
        @term_to_memberships_csv_filename[term_id] = csv_filename
      end
    end

    def run
      make_csv_files
      import_csv_files
    end

    def make_csv_files
      users_csv = make_users_csv(@users_csv_filename)
      known_uids = []
      Canvas::MaintainUsers.new.refresh_existing_user_accounts(known_uids, users_csv)
      original_user_count = known_uids.length
      cached_enrollments_provider = Canvas::TermEnrollmentsCsv.new
      @term_to_memberships_csv_filename.each do |term, csv_filename|
        enrollments_csv = make_enrollments_csv(csv_filename)
        refresh_existing_term_sections(term, enrollments_csv, known_uids, users_csv, cached_enrollments_provider)
        enrollments_csv.close
        enrollments_count = csv_count(csv_filename)
        logger.warn("Will upload #{enrollments_count} Canvas enrollment records for #{term}")
        @term_to_memberships_csv_filename[term] = nil if enrollments_count == 0
      end
      new_user_count = known_uids.length - original_user_count
      users_csv.close
      updated_user_count = csv_count(@users_csv_filename) - new_user_count
      logger.warn("Will upload #{updated_user_count} changed accounts for #{original_user_count} existing users")
      logger.warn("Will upload #{new_user_count} new user accounts")
      @users_csv_filename = nil if (updated_user_count + new_user_count) == 0
    end

    def refresh_existing_term_sections(term, enrollments_csv, known_uids, users_csv, cached_enrollments_provider)
      canvas_sections_csv = Canvas::SectionsReport.new.get_csv(term)
      return if canvas_sections_csv.empty?
      # Instructure doesn't guarantee anything about sections-CSV ordering, but we need to group sections
      # together by course site.
      course_id_to_csv_rows = canvas_sections_csv.group_by {|row| row['course_id']}
      course_id_to_csv_rows.each do |course_id, csv_rows|
        if course_id.present?
          sis_section_ids = csv_rows.collect { |row| row['section_id'] }
          sis_section_ids.delete_if {|section| section.nil? }
          # Process using cached enrollment data. See Canvas::TermEnrollmentsCsv
          Canvas::SiteMembershipsMaintainer.process(course_id, sis_section_ids, enrollments_csv, users_csv, known_uids, @batch_mode, cached_enrollments_provider)
        end
      end
    end

    # Uploading a single zipped archive containing both users and enrollments would be safer and more efficient.
    # However, a batch update can only be done for one term. If we decide to limit Canvas refreshes
    # to a single term, then we should change this code.
    def import_csv_files
      import_proxy = Canvas::SisImport.new
      if @users_csv_filename.blank? || import_proxy.import_users(@users_csv_filename)
        logger.warn("User import succeeded")
        @term_to_memberships_csv_filename.each do |term_id, csv_filename|
          if csv_filename.present?
            if @batch_mode
              import_proxy.import_batch_term_enrollments(term_id, csv_filename)
            else
              import_proxy.import_all_term_enrollments(term_id, csv_filename)
            end
          end
          logger.warn("Enrollment import for #{term_id} succeeded")
        end
      end
    end

  end
end
