require 'net/http'
require 'net/https'
require 'json'
require 'ostruct'
require 'greatschools/configuration'
require 'greatschools/model'
require 'greatschools/exceptions'
require 'querystring'
begin
  require 'typhoeus'
rescue LoadError => e
end

# Performs api calls to greatschools.
#
# === Supported Methods
#
# * +search+
# * +profile+
# * +tests+
#
# All methods return, so fields can be accessed with the dot operator. ex.
#
#   api = Greatschools::API.new
#   obj = api.search state: 'CA', q: 'alameda high', 
#   puts obj[0].title, obj[0].description, obj[0].thumbnail_url
#
# Call parameters should be passed as the opts parameter.  If set, key will
# automatically be added to the query string of the call, so no need to set it.
#

# SEARCH
# http://www.greatschools.org/api/docs/schoolSearch.page
# search  http://api.greatschools.org/search/schools/?[parameters]
# http://api.greatschools.org/search/schools?key=[yourAPIKey]&state=CA&q=Alameda&sort=alpha&levelCode=elementary-schools&limit=10

# PROFILE
# http://www.greatschools.org/api/docs/schoolProfile.page
# profile http://api.greatschools.org/schools/[components]?[parameters]
# http://api.greatschools.org/schools/CA/1?key=[yourkey]

# TESTS
# http://www.greatschools.org/api/docs/schoolTestScores.page
# http://api.greatschools.org/school/tests/[STATE]/[gsId]?[parameters]
# http://api.greatschools.org/school/tests/CA/1?key=[yourkey]

class Greatschools::API
  attr_reader :key, :hostname, :headers

  # === Options
  #
  # [:+hostname+] Hostname of greatschools server.  Defaults to api.greatschools.org.
  # [:+key+] Your greatschools api key.
  # [:+user_agent+] Your User-Agent header.  Defaults to Mozilla/5.0 (compatible; greatschools/VERSION;)
  # [:+timeout+] Request timeout (in seconds).  Defaults to 180 seconds or 3 minutes
  # [:+headers+] Additional headers to send with requests.
  def initialize opts={}
    @key = opts[:key]
    @hostname = opts[:hostname] || 'api.greatschools.org'
    @timeout = opts[:timeout] || 180
    @headers = {
      'User-Agent' => opts[:user_agent] || "Mozilla/5.0 (compatible; greatschools/#{Greatschools::VERSION};)"
    }.merge(opts[:headers]||{})
  end

  # <b>Search</b>
  #
  # State and query must be present
  #
  # === Options
  #
  # [:+q+] _(required)_     A query string to search
  # [:+state+] _(required)_ An two letter abreviation of a state for the search
  # [:+level+] _(optional)_ Level of school you wish to appear in the list, 
  #                         Valid values: "elementary-schools", "middle-schools", "high-schools"
  # [:+sort+] _(optional)_  This call by default sorts the results by relevance. If you want the results in alphabetical order, 
  #                         then use this parameter with a value of "alpha".
  # [:+limit+] _(optionsl)_ Maximum number of schools to return. This defaults to 200 and must be at least 1. Default is 10
  #
  def search opts
      # VALIDATE ARGS opts must include q and state 
  
      # BUILD PATH 
      path = "/search/schools?#{QueryString.stringify(params)}"

      # MAKE THE CALL
      response = _do_call path

      # VERIFY RESPONSE
      if response.code.to_i == 200
        logger.debug { response.body }
        # PARSE XML from response.body using Hash.from_xml
        # [].flatten is to be sure we have an array
        #results = .....
      else
        # RAISE EXCEPTION IF ERROR
        logger.debug { response }
        raise Greatschools::BadResponseException.new(response, path)
      end
  
      results
  end


  def _do_typhoeus_call path
    scheme, host, port = uri_parse hostname
    url = "#{scheme}://#{hostname}:#{port}#{path}"
    logger.debug { "calling #{site}#{path} with headers #{headers} using Typhoeus" }
    Typhoeus::Request.get(url, {:headers => headers, :timeout => (@timeout*1000) })
  end

  def _do_basic_call path
    scheme, host, port = uri_parse hostname
    logger.debug { "calling #{site}#{path} with headers #{headers} using Net::HTTP" }
    Net::HTTP.start(host, port) do |http|
      http.use_ssl = (scheme == 'https')
      http.read_timeout = @timeout
      http.get(path, headers)
    end
  end
  
  def _do_call path
      configuration.typhoeus ? _do_typhoeus_call(path) : _do_basic_call(path)
  end

  
  private
  def uri_parse uri
    uri =~ %r{^((http(s?))://)?([^:/]+)(:([\d]+))?(/.*)?$}
    scheme = $2 || 'http'
    host = $4
    port = $6 ? $6 : ( scheme == 'https' ? 443 : 80)
    [scheme, host, port.to_i]
  end

  def site
    scheme, host, port = uri_parse hostname
    if (scheme == 'http' and port == 80) or (scheme == 'https' and port == 443)
      "#{scheme}://#{host}"
    else
      "#{scheme}://#{host}:#{port}"
    end
  end

  def logger
    configuration.logger
  end

  def configuration
    Greatschools.configuration
  end
end
