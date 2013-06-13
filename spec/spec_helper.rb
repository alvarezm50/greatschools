require "greatschools"

RSpec.configure do |config|
  config.after do
    Greatschools.configuration.reset
  end
end
