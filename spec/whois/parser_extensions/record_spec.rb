require 'spec_helper'

describe Whois::Record do

  subject { described_class.new(server, parts) }

  let(:server) {
    Whois::Server.factory(:tld, ".foo", "whois.example.test")
  }
  let(:parts) {[
    Whois::Record::Part.new(body: "This is a record from foo.", host: "foo.example.test"),
    Whois::Record::Part.new(body: "This is a record from bar.", host: "bar.example.test")
  ]}
  let(:content) {
    parts.map(&:body).join("\n")
  }


  describe "#respond_to?" do
    before(:all) do
      @_properties  = Whois::Parser::PROPERTIES.dup
      @_methods     = Whois::Parser::METHODS.dup
    end

    after(:all) do
      Whois::Parser::PROPERTIES.clear
      Whois::Parser::PROPERTIES.push(*@_properties)
      Whois::Parser::METHODS.clear
      Whois::Parser::METHODS.push(*@_methods)
    end

    it "returns true if method is in self" do
      expect(subject.respond_to?(:to_s)).to be_truthy
    end

    it "returns true if method is in hierarchy" do
      expect(subject.respond_to?(:nil?)).to be_truthy
    end

    it "returns true if method is a property" do
      Whois::Parser::PROPERTIES << :test_property
      expect(subject.respond_to?(:test_property)).to be_truthy
    end

    it "returns true if method is a property?" do
      Whois::Parser::PROPERTIES << :test_property
      expect(subject.respond_to?(:test_property?)).to be_truthy
    end

    it "returns true if method is a method" do
      Whois::Parser::METHODS << :test_method
      expect(subject.respond_to?(:test_method)).to be_truthy
    end

    it "returns true if method is a method" do
      Whois::Parser::METHODS << :test_method
      expect(subject.respond_to?(:test_method?)).to be_truthy
    end
  end

  describe "#parser" do
    it "returns a Parser" do
      expect(subject.parser).to be_a(Whois::Parser)
    end

    it "initializes the parser with self" do
      expect(subject.parser.record).to be(subject)
    end

    it "memoizes the value" do
      expect(subject.instance_eval { @parser }).to be_nil
      parser = subject.parser
      expect(subject.instance_eval { @parser }).to be(parser)
    end
  end


  describe "#properties" do
    it "returns a Hash" do
      expect(subject.properties).to be_a(Hash)
    end

    it "returns both nil and not-nil values" do
      expect(subject).to receive(:domain).and_return("")
      expect(subject).to receive(:created_on).and_return(nil)
      expect(subject).to receive(:expires_on).and_return(Time.parse("2010-10-10"))

      properties = subject.properties
      expect(properties[:domain]).to eq("")
      expect(properties[:created_on]).to be_nil
      expect(properties[:expires_on]).to eq(Time.parse("2010-10-10"))
    end

    it "fetches all parser property" do
      expect(subject.properties.keys).to match(Whois::Parser::PROPERTIES)
    end
  end


  class Whois::Parsers::WhoisPropertiesTest < Whois::Parsers::Base
    property_supported :status do
      nil
    end
    property_supported :created_on do
      Date.parse("2010-10-20")
    end
    property_not_supported :updated_on
    # property_not_defined :expires_on
  end

  describe "#property_any_supported?" do
    it "delegates to parsers" do
      expect(subject.parser).to receive(:property_any_supported?).with(:example).and_return(true)
      expect(subject.property_any_supported?(:example)).to be_truthy
    end
  end

  describe "property" do
    it "returns value when the property is supported" do
      instance = described_class.new(nil, [Whois::Record::Part.new(body: "", host: "whois.properties.test")])
      expect(instance.created_on).to eq(Date.parse("2010-10-20"))
    end

    it "returns nil when the property is not supported" do
      instance = described_class.new(nil, [Whois::Record::Part.new(body: "", host: "whois.properties.test")])
      expect(instance.updated_on).to be_nil
    end

    it "returns nil when the property is not implemented" do
      instance = described_class.new(nil, [Whois::Record::Part.new(body: "", host: "whois.properties.test")])
      expect(instance.expires_on).to be_nil
    end
  end

  describe "property?" do
    it "returns true when the property is supported and has no value" do
      instance = described_class.new(nil, [Whois::Record::Part.new(body: "", host: "whois.properties.test")])
      expect(instance.status?).to eq(false)
    end

    it "returns false when the property is supported and has q value" do
      instance = described_class.new(nil, [Whois::Record::Part.new(body: "", host: "whois.properties.test")])
      expect(instance.created_on?).to eq(true)
    end

    it "returns false when the property is not supported" do
      instance = described_class.new(nil, [Whois::Record::Part.new(body: "", host: "whois.properties.test")])
      expect(instance.updated_on?).to eq(false)
    end

    it "returns false when the property is not implemented" do
      instance = described_class.new(nil, [Whois::Record::Part.new(body: "", host: "whois.properties.test")])
      expect(instance.expires_on?).to eq(false)
    end
  end


  describe "#changed?" do
    it "raises if the argument is not an instance of the same class" do
      expect {
        described_class.new(nil, []).changed?(Object.new)
      }.to raise_error(ArgumentError)

      expect {
        described_class.new(nil, []).changed?(described_class.new(nil, []))
      }.to_not raise_error
    end
  end

  describe "#unchanged?" do
    it "raises if the argument is not an instance of the same class" do
      expect {
        described_class.new(nil, []).unchanged?(Object.new)
      }.to raise_error(ArgumentError)

      expect {
        described_class.new(nil, []).unchanged?(described_class.new(nil, []))
      }.to_not raise_error
    end

    it "returns true if self and other references the same object" do
      instance = described_class.new(nil, [])
      expect(instance.unchanged?(instance)).to be_truthy
    end

    it "delegates to #parser if self and other references different objects" do
      other = described_class.new(nil, parts)
      instance = described_class.new(nil, parts)
      expect(instance.parser).to receive(:unchanged?).with(other.parser)

      instance.unchanged?(other)
    end
  end

  describe "#contacts" do
    it "delegates to parser" do
      expect(subject.parser).to receive(:contacts).and_return([:one, :two])
      expect(subject.contacts).to eq([:one, :two])
    end
  end


  describe "#response_incomplete?" do
    it "delegates to #parser" do
      expect(subject.parser).to receive(:response_incomplete?)
      subject.response_incomplete?
    end
  end

  describe "#response_throttled?" do
    it "delegates to #parser" do
      expect(subject.parser).to receive(:response_throttled?)
      subject.response_throttled?
    end
  end

  describe "#response_unavailable?" do
    it "delegates to #parser" do
      expect(subject.parser).to receive(:response_unavailable?)
      subject.response_unavailable?
    end
  end


  describe "method_missing" do
    context "when a parser property"
    context "when a parser method"

    context "when a parser question method/property" do
      it "calls the corresponding no-question method" do
        expect(subject).to receive(:status)
        subject.status?
      end

      it "returns true if the property is not nil" do
        expect(subject).to receive(:status).and_return("available")
        expect(subject.status?).to eq(true)
      end

      it "returns false if the property is nil" do
        expect(subject).to receive(:status).and_return(nil)
        expect(subject.status?).to eq(false)
      end
    end

    context "when a simple method" do
      it "passes the request to super" do
        Object.class_eval do
          def happy; "yes"; end
        end

        record = described_class.new(nil, [])
        expect {
          expect(record.happy).to eq("yes")
        }.to_not raise_error
        expect {
          record.sad
        }.to raise_error(NoMethodError)
      end

      it "does not catch all methods" do
        expect {
          described_class.new(nil, []).i_am_not_defined
        }.to raise_error(NoMethodError)
      end

      it "does not catch all question methods" do
        expect {
          described_class.new(nil, []).i_am_not_defined?
        }.to raise_error(NoMethodError)
      end
    end
  end

end
