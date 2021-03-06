require File.expand_path("../spec_helper", __FILE__)

describe "Keen IO API" do
  let(:project_id) { ENV['KEEN_PROJECT_ID'] }
  let(:write_key) { ENV['KEEN_WRITE_KEY'] }

  describe "publishing" do
    let(:collection) { "users" }
    let(:event_properties) { { "name" => "Bob" } }
    let(:api_success) { { "created" => true } }

    describe "success" do
      it "should return a created status for a valid post" do
        Keen.publish(collection, event_properties).should == api_success
      end
    end

    describe "failure" do
      it "should raise a not found error if an invalid project id" do
        client = Keen::Client.new(:project_id => "riker", :write_key => "whatever")
        expect {
          client.publish(collection, event_properties)
        }.to raise_error(Keen::NotFoundError)
      end

      it "should succeed if a non-url-safe event collection is specified" do
        Keen.publish("infinite possibilities", event_properties).should == api_success
      end
    end

    describe "async" do
      # no TLS support in EventMachine on jRuby
      unless defined?(JRUBY_VERSION)

        it "should publish the event and trigger callbacks" do
          EM.run {
            Keen.publish_async(collection, event_properties).callback { |response|
              begin
                response.should == api_success
              ensure
                EM.stop
              end
            }.errback { |error|
              EM.stop
              fail error
            }
          }
        end

        it "should publish to non-url-safe collections" do
          EM.run {
            Keen.publish_async("foo bar", event_properties).callback { |response|
              begin
                response.should == api_success
              ensure
                EM.stop
              end
            }
          }
        end
      end
    end
  end

  describe "queries" do
    let(:read_key) { ENV['KEEN_READ_KEY'] }
    let(:event_collection) { @event_collection }
    let(:returns_event_collection) { @returns_event_collection }

    before(:all) do
      @event_collection = "purchases_" + rand(100000).to_s
      @returns_event_collection = "returns_" + rand(100000).to_s

      Keen.publish(@event_collection, {
        :username => "bob",
        :price => 10
      })
      Keen.publish(@event_collection, {
        :username => "ted",
        :price => 20
      })
      Keen.publish(@returns_event_collection, {
        :username => "bob",
        :price => 30
      })
      sleep(5)
    end

    it "should return a valid count" do
      Keen.count(event_collection).should == 2
    end

    it "should return a valid count_unique" do
      Keen.count_unique(event_collection, :target_property => "price").should == 2
    end

    it "should return a valid sum" do
      Keen.sum(event_collection, :target_property => "price").should == 30
    end

    it "should return a valid minimum" do
      Keen.minimum(event_collection, :target_property => "price").should == 10
    end

    it "should return a valid maximum" do
      Keen.maximum(event_collection, :target_property => "price").should == 20
    end

    it "should return a valid average" do
      Keen.average(event_collection, :target_property => "price").should == 15
    end

    it "should return a valid select_unique" do
      results = Keen.select_unique(event_collection, :target_property => "price")
      results.sort.should == [10, 20].sort
    end

    it "should return a valid extraction" do
      results = Keen.extraction(event_collection)
      results.length.should == 2
      results.all? { |result| result["keen"] }.should be_true
    end

    it "should return a valid funnel" do
      steps = [{
        :event_collection => event_collection,
        :actor_property => "username"
      }, {
        :event_collection => @returns_event_collection,
        :actor_property => "username"
      }]
      results = Keen.funnel(:steps => steps)
      results.should == [2, 1]
    end

    it "should apply filters" do
      Keen.count(event_collection, :filters => [{
        :property_name => "username",
        :operator => "eq",
        :property_value => "ted"
      }]).should == 1
    end
  end
end
