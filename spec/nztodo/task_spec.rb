require 'nztodo/task'

module NZTodo
  class List ; end
  module Validate ; end
  module UUID ; end


  RSpec.describe Task do

    let(:id) { 'f96a3114-c133-4063-9f8f-f2f722dea355' }
    before(:each) do
      allow(UUID).to receive(:new).and_return(id)
    end

    context 'normalize' do
      let(:data){ { 'name' => 'task name', 'completed' => true } }

      before(:each) do
        allow(Validate).to receive(:validate_data)
      end

      it 'accepts valid data do' do
        expect{Task.normalize(data)}.to_not raise_error
      end

      it 'adds default completed' do
        data.delete('completed')
        Task.normalize(data)
        expect(data['completed']).to eq(false)
      end

      it 'validates the data' do
        expect(Validate).to receive(:validate_data).with(data, {'name' => String, 'completed' => :bool})
        Task.normalize(data)
      end
    end

    context 'build' do
      let(:name) { 'task 1'}
      let(:completed) { false }
      let(:task_array) { [] }
      let(:task_hash) { {} }
      let(:args){ [{'id' =>id, 'name' => name, 'completed' => completed}, task_array, task_hash] }


      %i{id name completed}.each do |attr|
        it "builds a task with the given #{attr}" do
          expect(Task.build(*args).send(attr)).to eq(send(attr))
        end
      end

      it 'adds the task to the provided list' do
        task = Task.build(*args)
        expect(task_array.last).to eq(task)
      end

      it 'adds the task to the provided hash' do
        task = Task.build(*args)
        expect(task_hash[task.id]).to eq(task)
      end
    end

    context 'create' do
      before(:each) do
        @task = double('Task', :id => '16b93225-e7c0-457b-8b80-dbdcce28a428')
        @list = double('List', :add_task => @task)
        allow(List).to receive(:retrieve).and_return(@list)
        allow(Validate).to receive(:validate_data)
      end

      let(:name) { 'task 2' }
      let(:list_id) { '8b3dab45-30c3-41c2-ac2c-7e6f0a89123e' }
      let(:normalized_data) { {'name' => name, 'completed' => false} }

      it 'retreived the specified list' do
        expect(List).to receive(:retrieve).with(list_id)
        Task.create(list_id, {'name' => name})
      end

      it 'adds a task to the retreived list with normalized data' do
        expect(@list).to receive(:add_task).with(normalized_data)
        Task.create(list_id, {'name' => name})
      end

      it 'returns the id of the created task' do
        expect(Task.create(list_id, {'name' => name})).to eq(@task.id)
      end
    end

    context 'retrieve' do
      let(:task) { Task.new('bee3bedf-d8c4-4cc6-b1d6-656407db6bbe', 'task 3', false, [], {}) }
      let(:list_id) { 'cf36fafa-9e95-45f1-a01c-16dfffc07402' }

      before(:each) do
        @list = double("List", :retrieve => task)
        allow(List).to receive(:retrieve).and_return(@list)
      end

      it 'retrieves' do
        expect(Task.retrieve(list_id, task.id)).to eq(task)
      end
    end

    context 'complete' do
      let(:task) { Task.new('bee3bedf-d8c4-4cc6-b1d6-656407db6bbe', 'task 3', false, [], {}) }
      let(:list_id) { 'cf36fafa-9e95-45f1-a01c-16dfffc07402' }
      let(:completed_value) { true }
      let(:completed_data) { { 'completed' => completed_value } }

      before(:each) do
        @list = double("List", :retrieve => task)
        allow(List).to receive(:retrieve).and_return(@list)
        allow(Validate).to receive(:validate_data)
        allow(Validate).to receive(:check_uuid)
      end

      it 'updates the task' do
        completed_value = true
        Task.complete(list_id, id, completed_data)
        expect(task.completed).to eq(completed_value)
      end

      it 'retrieves the list by its id' do
        expect(List).to receive(:retrieve).with(list_id)
        Task.complete(list_id, id, completed_data)
      end

      it 'retrieves the task from the list by its id' do
        expect(@list).to receive(:retrieve).with(id)
        Task.complete(list_id, id, completed_data)
      end

      it 'validates the data' do
        expect(Validate).to receive(:validate_data).with(completed_data, {'completed' => :bool})
        Task.complete(list_id, id, completed_data)
      end

      it 'returns' do
        expect(Task.complete(list_id, id, completed_data)).to be(task)
      end
    end

    context 'json' do
      let(:attr_args) { ['cf7cfcc2-3f63-4f8b-9f1f-2fd4e0be89bb', 'task 4', true] }
      let(:task) { Task.new(*attr_args, [], {}) }
      it 'returns the id, name, and completed' do
        hash_args = {}
        %w{id name completed}.zip(attr_args).each{|key, value| hash_args[key] = value}
        expect(task.to_json).to eq(hash_args.to_json)
      end
    end
  end
end

