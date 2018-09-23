require 'nztodo/list'
require 'json'


module NZTodo
  class Task ; end
  module Validate ; end
  module UUID ; end

# Rather than putting a test method on List, and leaving it "out there", I am
# putting it here.

# TODO: Have these method defined only in the contexts of this file.
  class List
    def self.[](id)
      @lists[id]
    end
    attr_reader :tasks_hash
  end

  RSpec.describe List do
    module ClearLists
      def clear_lists
        [:@lists, :@lists_list].each do |ivar|
          List.instance_variable_get(ivar).clear
        end
      end
    end

    let(:id) { "ac6cacd9-76bb-4a0f-8317-5928c870be62" }

    context '.retrieve' do
      include ClearLists

      before(:each) do
        @hash, lists = [:@lists, :@lists_list].map{|ivar| List.send(:instance_variable_get, ivar)}
        @list = List.new(id, 'list name', 'list_description', [], @hash, lists)
        allow(Validate).to receive(:fetch).and_return(@list)
      end

      after(:example) do
        clear_lists
      end

      it 'retrieves a list by its id' do
        expect(List.retrieve(id)).to eq(@list)
      end

      it 'fetches the list' do
        expect(Validate).to receive(:fetch).with(@hash, id, 'List')
        List.retrieve(id)
      end
    end

    context 'create' do
      include ClearLists

      after(:context) do
        clear_lists
      end

      def json_norm(data)
        JSON.load(data.to_json)
      end

      before(:each) do
        allow(Validate).to receive(:validate_data)
        allow(UUID).to receive(:new).and_return(id)
      end

      it 'creates a new list' do
        data = {'name' => 'list 1', 'description' => 'What this list does', 'tasks' => []}
        id = List.create(data).first
        expect(json_norm(List[id])).to eq(data.merge('id' => id))
      end

      it 'issues a uuid for a new list' do
        data = {'name' => 'list 1', 'description' => 'What this list does', 'tasks' => []}
        list_id = List.create(data).first
        expect(list_id).to eq(id)
      end

      it 'creates a new list with defaults' do
        data = {'name' => 'list 2'}
        id = List.create(data).first
        expect(json_norm(List[id])).to eq(data.merge('id' => id, 'description' => '', 'tasks' => []))
      end

      it 'validates the data' do
        data = {'name' => 'list 1', 'description' => 'What this list does', 'tasks' => []}
        expect(Validate).to receive(:validate_data).with(data,
          {'name' => String, 'description' => String, 'tasks' => Array})
        List.create(data)
      end

      context 'with tasks data' do
# These names are NOT "usual".  They do allow me to drive the cheezy hack below
        let(:tasks_data) { [{'name' => '0'}, {'name' => '1'}, {'name' => '2'}] }
        let(:normalized_tasks_data) { tasks_data.map{|datum| {'completed' => false}.merge(datum)} }
        let(:task_ids) { [
            "80c5b220-2d49-40f5-ba31-932143b52a38",
            "21c8f985-2392-4f23-9f8e-56372762ee5c",
            "4723563b-c9e9-4c33-a9bb-0d254807b853",
          ] }
        let(:tasks) {tasks_data.zip(task_ids).map do |datum, id|
            double("task_#{datum['name']}", :id => id, :name => datum['name'])
          end
        }
        let(:list_data) { {'name' => 'list 5', 'tasks' => tasks_data} }

        let(:list) {
          List.new(id, list_data['name'], '', tasks_data, {}, [])
        }

        before(:each) do
          allow(Task).to receive(:normalize){|td| td['completed'] = false}
# Cheezy hack.  See above.
          allow(Task).to receive(:build) do |td, array|
            array << tasks[td['name'].to_i]
          end
          allow(Validate).to receive(:validate_data)
        end

        it 'normalizes the data for each task' do
          tasks_data.each do |datum|
            expect(Task).to receive(:normalize).with(datum)
          end

          List.create(list_data)
        end

        it 'builds each task' do
          normalized_tasks_data.each do |datum|
            expect(Task).to receive(:build).with(datum, any_args)
          end

          List.create(list_data)
        end

        it 'attaches the built tasks to the list' do
          id = List.create(list_data).first
          list = List[id]
          expect(list.tasks).to eq(tasks)
        end

        it 'returns the id of the tasks under the id of the list' do
          expect(List.create(list_data)[1]).to eq(tasks.map{|task| task.id})
        end
      end
    end

    context 'list' do
      include ClearLists

      let(:skip) { 3 }
      let(:limit) { 5 }

      def json_norm(data)
        JSON.load(data.to_json)
      end

      before(:context) do
        clear_lists
        hashl, listls = [:@lists, :@lists_list].map{|ivar| List.send(:instance_variable_get, ivar)}
        @lists = ('a'..'o').map do |char|
          name = (0..9).map{|offset| (char.ord + offset).chr} * ''
          id = 'd9716c20-4d18-4cc0-a7a9-29fe5b6ef2' + '%02x' % char.ord
          json_norm(List.new(id, name, 'list_description', [], hashl, listls))
        end
      end

      before(:each) do
        allow(Validate).to receive(:validate_data)
      end

      after(:context) do
        clear_lists
      end

      it 'retrieves all lists' do
        expect(json_norm(List.list({}))).to eq(@lists)
      end

      it 'skips lists as directed' do
        expect(json_norm(List.list({'skip' => skip.to_s}))).to eq(@lists[skip..-1])
      end

      it 'limits the return count as directed' do
        expect(json_norm(List.list({'skip' => skip.to_s, 'limit' => limit.to_s}))).to eq(@lists[skip, limit])
      end

      it 'searches substrings' do
        expect(json_norm(List.list({'search' => 'jkl'}))).to eq(@lists[2,8])
      end

      it 'skips and limits with search substrings' do
        params = {'search' => 'jkl', 'skip' => skip.to_s, 'limit' => limit.to_s}
        expect(json_norm(List.list(params))).to eq(@lists[2 + skip, limit])
      end

      it 'validates the search parameters' do
        data = {'search' => 'jkl', 'skip' => skip.to_s, 'limit' => limit.to_s}
        spec = {'search' => String, 'skip' => :uint32_string, 'limit' => :uint32_string}
        expect(Validate).to receive(:validate_data).with(data, spec)
        List.list(data)
      end
    end

    context '#add_task' do
      let(:task_data) { {'name' => 'task 7', 'completed' => false} }

# Note: Task.build adds the task to the list.

      it 'builds the task with the provided data and the list tracking objects' do
        list = List.new(id, 'list 6', '', [], {}, [])
        expect(Task).to receive(:build).with(task_data, list.tasks, list.instance_variable_get(:@tasks_hash))
        list.add_task(task_data)
      end

    end

    context '#retrieve' do
      let(:list){ List.new('381dbddd-7ab6-4c5c-a09d-2cf03d7b2315', 'list 8', '', [{'name' => 'task 9'}], {}, []) }

      before(:each) do
        @task = double('task 9', :id => id)
        allow(Task).to receive(:build) do |data, task_list, task_hash|
          task_list << @task
          task_hash[id] = @task
        end
        allow(Validate).to receive(:fetch).and_return(@task)
      end

      it 'retrieves a task by its id' do
        expect(list.retrieve(id)).to eq(@task)
      end

      it 'fetches the task' do
        expect(Validate).to receive(:fetch).with(list.tasks_hash, id, 'Task')
        list.retrieve(id)
      end
    end

    context '#to_json' do
      it 'returns the id, name, description and task list' do
        attr_args = [
          '381dbddd-7ab6-4c5c-a09d-2cf03d7b2315',
          'list 9',
          'describe',
          []
        ]
        list = List.new(*attr_args, {}, [])
        hash_args = {}
        %w{id name description tasks}.zip(attr_args).each{|key, value| hash_args[key] = value}
        expect(list.to_json).to eq(hash_args.to_json)
      end
    end
  end
end



