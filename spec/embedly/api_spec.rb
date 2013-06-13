require "spec_helper"

module Greatschools
  describe API do
    let(:api) { API.new :key => ENV['GREATSCHOOLS_KEY'] }

    describe "logger" do
      let(:io) { StringIO.new }

      before do
        Greatschools.configure do |c|
          c.debug  = true
          c.logger = Logger.new(io)
        end
      end

      it "logs if debug is enabled" do
        api.search  query: 'Alameda High', state: 'MA'
        io.string.should =~ %r{.*DEBUG -- : .*}
      end
    end
  end
end
