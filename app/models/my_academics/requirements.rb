# TODO collapse this class into Bearfacts::Profile
module MyAcademics
  class Requirements
    include AcademicsModule

    def merge(data, law_student=false)
      profile_proxy = Bearfacts::Profile.new({:user_id => @uid})
      doc = profile_proxy.get[:xml_doc]
      return data if doc.blank? #|| law_student # Joel added the '|| @law_student'

      requirements = []
      if law_student
        # Get Law School requirements, check here
      else
        req_nodes = doc.css("underGradReqProfile")
        req_nodes.children().each do |node|
          name = node.name
          status = node.text.upcase == "REQT SATISFIED" ? "met" : ""
          # translate requirement names to English
          case node.name.upcase
          when "SUBJECTA"
            name = "UC Entry Level Writing"
          when "AMERICANHISTORY"
            name = "American History"
          when "AMERICANINSTITUTIONS"
            name = "American Institutions"
          when "AMERICANCULTURES"
            name = "American Cultures"
          end
        end

        requirements << {
          name: name,
          status: status
        }
      end

      data[:requirements] = requirements
    end
  end
end
