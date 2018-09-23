require 'nztodo/uuid'

module SecureRandom ; end

module NZTodo
  RSpec.describe UUID do
    let(:previous_id) {'6363c342-bec9-4577-9fdd-ad0139b614ce'}

    let(:uuid) { '75798dd7-8d8b-4e0d-9c0d-28eccae59775' }

    it 'calls SecureRandom.uuid' do
      expect(SecureRandom).to receive(:uuid)
      UUID.new({})
    end

    it 'returns the result from SecureRandom.uuid' do
      expect(SecureRandom).to receive(:uuid).and_return(uuid)
      expect(UUID.new({})).to eq(uuid)
    end

    it 'calls SecureRandom.uuid until it returns a new value' do
      expect(SecureRandom).to receive(:uuid).exactly(3).times.and_return(previous_id, previous_id, uuid)
      expect(UUID.new({previous_id => nil})).to eq(uuid)
    end
  end
end

