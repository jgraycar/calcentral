module MyAcademics
  class GpaUnits
    include AcademicsModule

    def merge(data, law_student=false)
      student_info = CampusOracle::Queries.get_student_info(@uid) || {}
      return data if student_info.nil? #|| law_student # Joel added the '|| @law_student'

      # data[:gpaUnits] = {
      #   cumulativeGpa: student_info["cum_gpa"].nil? ? nil: student_info["cum_gpa"].to_f,
      #   totalUnits: student_info["tot_units"].nil? ? nil : student_info["tot_units"].to_f
      # }

      if law_student
        # Ideally, get from API here
        # May have issue later if require float; need to see how used down the line
        data[:gpaUnits] = {
          cumulativeGpa: "N/A",
          totalUnits: "N/A"
        }
      else
        data[:gpaUnits] = {
          cumulativeGpa: student_info["cum_gpa"].nil? ? nil: student_info["cum_gpa"].to_f,
          totalUnits: student_info["tot_units"].nil? ? nil : student_info["tot_units"].to_f
        }
      end
    end
  end
end
