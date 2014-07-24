# TODO collapse this class into Bearfacts::Regblocks
module MyAcademics
  class Regblocks

    include AcademicsModule
    include DatedFeed

    def merge(data, law_student=false)
      data[:regblocks] = Bearfacts::MyRegBlocks.new(@uid).get_feed
    end
  end
end
