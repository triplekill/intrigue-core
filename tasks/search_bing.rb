class SearchBingTask < BaseTask

  def metadata
    {
      :name => "search_bing",
      :pretty_name => "Search Bing",
      :authors => ["jcran"],
      :description => "This task hits the Bing API and finds related content. Discovered domains are created",
      :references => [],
      :allowed_types => ["*"],
      :example_entities => [{:type => "String", :attributes => {:name => "intrigue.io"}}],
      :allowed_options => [],
      :created_types => ["DnsRecord","EmailAddress","PhoneNumber","WebAccount", "Uri"]
    }
  end

  ## Default method, subclasses must override this
  def run
    super

    # Make sure the key is set
    api_key = _get_global_config "bing_api_key"
    entity_name = _get_entity_attribute "name"

    # Attach to the google service & search
    bing = Client::Search::Bing::SearchService.new(api_key,50,'Web',{:Adult => 'Off'})
    results = bing.search(entity_name)

    # the first result will often be our domain, so save that.
    main_uri = results.first[:Web].first[:DisplayUrl].split(".").last(2).join(".")

    results.first[:Web].each do |result|

      # a result will look like:
      #
      # {:__metadata=>
      # {:uri=>"https://api.datamarket.azure.com/Data.ashx/Bing/Search/v1/ExpandableSearchResultSet(guid'3033f6e3-d175-418c-a201-4a0c2c643384')/Web?$skip=0&$top=1", :type=>"WebResult"},
      # :ID=>"d30722c1-3fab-4ad6-90b1-aa136224afe4",
      # :Title=>"Speedtest.net by Ookla - The Global Broadband Speed Test",
      # :Description=>"Test your Internet connection bandwidth to locations around the world with this interactive broadband speed test from Ookla",
      # :DisplayUrl=>"www.speedtest.net",
      # :Url=>"http://www.speedtest.net/"}
      #

      # XXX - untrusted input
      unless _prohibited_entity(result)

        # Create the specific page
        _create_entity("Uri",     {     :name => result[:Url],
                                        :uri => result[:Url],
                                        :description => result[:Description],
                                        :title => result[:Title],
                                        :source => "Bing"
                                    })

        # Create a domain if it matches our search string or the main URI
        dns_name = result[:DisplayUrl].split("/").first
        @task_log.log "main_uri: #{main_uri}"
        @task_log.log "dns_name: #{dns_name}"
        @task_log.log "entity_name: #{entity_name}"
        if /#{entity_name}/ =~ dns_name || /#{main_uri}/ =~ dns_name
          _create_entity("DnsRecord", { :name => dns_name })
        end

      end

      ### XXX -  Thinking this needs to be stuck in a library somewhere
      _parse_web_account_from_uri(result[:Url])

      # Check for Phone Number
      if result[:Description].match(/(\+\d{1,2}\s)?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}/)
        # Grab all matches
        matches = result[:Description].scan(/((\+\d{1,2}\s)?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4})/)
        matches.each do |match|
          _create_entity("PhoneNumber", { :name => "#{match[0]}" })
        end
      # Check for Email Address
      elsif result[:Description].match(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}\b/i)
        # Grab all matches
        matches = result[:Description].scan(/((\+\d{1,2}\s)?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4})/)
        matches.each do |match|
          _create_entity("EmailAddress", { :name => "#{match[0]}" })
        end
      end

    end # end results.each
  end # end run()

  private

    def _parse_web_account_from_uri(url)
      # Handle Twitter search results
      if url =~ /https?:\/\/twitter.com\/.*$/
        account_name = url.split("/")[3]
        _create_entity("WebAccount", {
          :domain => "twitter.com",
          :name => account_name,
          :uri => "#{url}",
          :type => "full"
        })

      # Handle Facebook public profile  results
      elsif url =~ /https?:\/\/www.facebook.com\/(public|pages)\/.*$/
        account_name = url.split("/")[4]
        _create_entity("WebAccount", {
          :domain => "facebook.com",
          :name => account_name,
          :uri => "#{url}",
          :type => "public"
        })

      # Handle Facebook search results
      elsif url =~ /https?:\/\/www.facebook.com\/.*$/
        account_name = url.split("/")[3]
        _create_entity("WebAccount", {
          :domain => "facebook.com",
          :name => account_name,
          :uri => "#{url}",
          :type => "full"
        })

      # Handle LinkedIn public profiles
      elsif url =~ /^https?:\/\/www.linkedin.com\/in\/pub\/.*$/
          account_name = url.split("/")[5]
          _create_entity("WebAccount", {
            :domain => "linkedin.com",
            :name => account_name,
            :uri => "#{url}",
            :type => "public"
          })

      # Handle LinkedIn public directory search results
      elsif url =~ /^https?:\/\/www.linkedin.com\/pub\/dir\/.*$/
        account_name = "#{url.split("/")[5]} #{url.split("/")[6]}"
        _create_entity("WebAccount", {
          :domain => "linkedin.com",
          :name => account_name,
          :uri => "#{url}",
          :type => "public"
        })

      # Handle LinkedIn world-wide directory results
      elsif url =~ /^http:\/\/[\w]*.linkedin.com\/pub\/.*$/

      # Parses these URIs:
      #  - http://za.linkedin.com/pub/some-one/36/57b/514
      #  - http://uk.linkedin.com/pub/some-one/78/8b/151

        account_name = url.split("/")[4]
        _create_entity("WebAccount", {
          :domain => "linkedin.com",
          :name => account_name,
          :uri => "#{url}",
          :type => "public" })

      # Handle LinkedIn profile search results
      elsif url =~ /^https?:\/\/www.linkedin.com\/in\/.*$/
        account_name = url.split("/")[4]
        _create_entity("WebAccount", {
          :domain => "linkedin.com",
          :name => account_name,
          :uri => "#{url}",
          :type => "public" })

      # Handle Google Plus search results
      elsif url =~ /https?:\/\/plus.google.com\/.*$/
        account_name = url.split("/")[3]
        _create_entity("WebAccount", {
          :domain => "google.com",
          :name => account_name,
          :uri => "#{url}",
          :type => "full" })

      # Handle Hackerone search results
      elsif url =~ /https?:\/\/hackerone.com\/.*$/
        account_name = url.split("/")[3]
        _create_entity("WebAccount", {
          :domain => "hackerone.com",
          :name => account_name,
          :uri => url,
          :type => "full" }) unless account_name == "reports"
      end
end

  def _prohibited_entity(result)
    return true if (result[:Url] =~ /wikipedia/ ||
                    result[:Url] =~ /linkedin/  ||
                    result[:Url] =~ /facebook/  ||
                    result[:Url] =~ /twitter/)
  false
  end
end # end Class
