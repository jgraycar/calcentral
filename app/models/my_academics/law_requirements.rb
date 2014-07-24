# TODO collapse this class into Bearfacts::Profile
module MyAcademics
  class Requirements
    include AcademicsModule

    def merge(data)
      profile_proxy = Bearfacts::Profile.new({:user_id => @uid})
      doc = profile_proxy.get[:xml_doc]
      return data if doc.blank?

      requirements = []
      # somehow get requirements as a class with accessor methods name & status
      # status should be either "met" if met or "" if not yet
      law_requirements = get_law_requirements_somehow()
      law_requirements.each do |req|
        name = req.name
        status = req.status
        # Might have to make name prettier here; see requirements.rb for example
        requirements << {
          name: name,
          status: status
        }
      end

      data[:requirements] = requirements
    end
  end
end
