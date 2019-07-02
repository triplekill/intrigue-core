module Intrigue
module Task
class SearchGrayhatWarfare < BaseTask

  def self.metadata
    {
      :name => "search_grayhat_warfare",
      :pretty_name => "Search Grayhat Warfare",
      :authors => ["jcran"],
      :description => "This task hits the Grayhat Warfare API and finds buckets.",
      :references => [],
      :type => "discovery",
      :passive => true,
      :allowed_types => ["String"],
      :example_entities => [{"type" => "String", "details" => {"name" => "intrigue.io"}}],
      :allowed_options => [
        {:name => "max_buckets", :regex => "integer", :default => 100 }
      ],
      :created_types => ["AwsS3Bucket"]
    }
  end

  ## Default method, subclasses must override this
  def run
    super

    # Make sure the key is set
    api_key = _get_task_config("grayhat_warfare_api_key")

    search_string = _get_entity_name
    search_uri = "https://buckets.grayhatwarfare.com/api/v1/buckets/0/#{max_buckets}?access_token=#{api_key}&keywords=#{search_string}"

    output = JSON.parse(http_get_body(search_uri))
    output["buckets"].each do |b|
      # {"id":21,"bucket":"0x4e84.test.s3-eu-west-1.amazonaws.com"}
      _create_entity "AwsS3Bucket", { 
        "name" => "https://#{b["bucket"]}",
        "uri" => "https://#{b["bucket"]}"
      }
    end

    
  end # end run

end
end
end
