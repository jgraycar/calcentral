module MyAcademics
  class GpaUnits
    include AcademicsModule

    def merge(data)
      student_info = CampusOracle::Queries.get_student_info(@uid) || {}
      return data if student_info.nil?

      # to ask Devin:
      # 1. how can we get their law-school equivalent of gpa?
      # 2. Does CampusOracle have their correct amount of total units,
      # or need some other way of getting?
      data[:gpaUnits] = {
        cumulativeGpa: "Not Applicable",
        totalUnits: student_info["tot_units"].nil? ? nil : student_info["tot_units"].to_f
      }
    end
  end
end
