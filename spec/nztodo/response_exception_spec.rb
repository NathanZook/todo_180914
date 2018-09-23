require 'nztodo/validate'

module NZTodo

  RSpec.shared_examples "a request exception" do |code|
    let(:message) { "Some string" }
    let(:exception) { described_class.new(message) }

    it 'is a runtime error' do
      expect(exception).to be_kind_of(RuntimeError)
    end

    it "intializes with the message" do
      expect(exception.message).to eq(message.to_json)
    end

    it "has the right code" do
      expect(exception.http_status).to eq(code)
    end
  end

  RSpec.describe BadRequest do
    it_should_behave_like "a request exception", 400
  end

  RSpec.describe NotFound do
    it_should_behave_like "a request exception", 404
  end

  RSpec.describe Conflict do
    it_should_behave_like "a request exception", 409
  end

end

