require 'nztodo_core'

# This is an integration test of the core of the application.

module NZTodo
  RSpec.describe 'core' do
    None = Object.new

    def list_specs_to_data(specs)
      specs.map do |list_spec|
        list_data = {}
        if list_spec.last.is_a?(Array)
          tasks_data = list_spec.last.map do |task_spec|
            task_data = {}
            %w{name completed}.zip(task_spec).each do |key, value|
              task_data[key] = value if value != None
            end
            task_data
          end
          list_spec[-1] = tasks_data
        end

        %w{name description tasks}.zip(list_spec) do |key, value|
          list_data[key] = value if value != None
        end

        list_data
      end
    end

    def transform_task_spec(list_id, name, completed, error)
      data = {'name' => name}
      data['completed'] = completed if completed != None
      [ list_id, data, error ]
    end

    def change_hex(string)
      string.tr('0123456789abcdef', '89abcdef01234567')
    end

    before(:context) do
      [:@lists, :@lists_list].each do |ivar|
        NZTodo::List.instance_variable_get(ivar).clear
      end
    end

    it 'operations demo' do
      good_list_specs = [
        [ 'list 1', None, None ],
        [ 'list 2 AAA', 'description 2', None ],
        [ 'list 3 AAA', None, [] ],
        [ 'list 4 AAA', 'description 4', [] ],
        [ 'list 5 AAA', 'description 5',
          [
            [ 'task 1', None ],
            [ 'task 2', true ],
            [ 'task 3', false ],
          ]
        ],
      ]
# Creation creates
      list_ids = list_specs_to_data(good_list_specs).map{|data| List.create(data) }
      first_list_id = list_ids.first.first
      last_list_id = list_ids.last.first

      bad_list_specs = [
        [ None, 'description 6', [] ],
        [ 1, None, None ],
        [ 'list 8', 5, None ],
        [ 'list 9', None, [ [ None, false ] ] ],
        [ 'list 10', None, [ [ 'task 5', 1 ] ] ],
        [ 'list 11', None, {} ],
        [ 'list 12', None, [ [ 'task 6', false ], [ None, false] ] ],
      ]
# Creation can fail
      list_specs_to_data(bad_list_specs.append([])).each do |data|
        expect{List.create(data)}.to raise_error(BadRequest)
      end

# List works.  Also checks creation took.
      expect(List.list({}).map{|list| list.name}).to eq(good_list_specs.map{|spec| spec[0]})
      list_params = {'skip' => '1', 'limit' => '2', 'search' => 'AAA'}
      expected_ids = list_ids[2..3].map{|id| id.first}
      expect(List.list(list_params).map{|list| list.id}).to eq(expected_ids)


# Retrieve works
      sample_index = 1
      expect(List.retrieve(list_ids[sample_index].first).name).to eq(good_list_specs[sample_index][0])

# Default values for list creation
      first_list = List.retrieve(first_list_id)
      expect(first_list.as_json['description']).to eq('')
      expect(first_list.tasks.length).to eq(0)

      last_list = List.retrieve(last_list_id)
      last_list_task_initial_count = good_list_specs.last.last.length
      expect(last_list.tasks[0].completed).to equal(false)
      expect(last_list.tasks.length).to eq(last_list_task_initial_count)

# Create Tasks
      good_task_specs = [
        [first_list_id, 'task 7', None, None],
        [last_list_id, 'task 8', true, None],
      ].map{|spec| transform_task_spec(*spec) }
      task_ids = good_task_specs.map{|list_id, data, not_used| Task.create(list_id, data)}

# Failing task creation is...more complicated
      chars = []
      list_ids.each_with_index do |id, index|
        chars.unshift(change_hex(id.first[-1-index]))
      end
      cantor_list_id = '00000000-0000-0000-0000-' + '0' * (12 - list_ids.length) + chars.join('')
      bad_task_specs = [
        [cantor_list_id, 'task 9', false, NotFound],
        [first_list_id, None, false, BadRequest],
        [first_list_id, 'task 11', nil, BadRequest],
        [1, 'task 12', false, BadRequest],
      ].map{|spec| transform_task_spec(*spec) }
      bad_task_specs.append([first_list_id, [], BadRequest]).each do |list_id, data, error|
        expect{Task.create(list_id, data)}.to raise_error(error)
      end

# Checking here to ensure that bad tasks were not in fact created.
      expect(first_list.tasks.length).to eq(1)
      expect(last_list.tasks.length).to eq(last_list_task_initial_count + 1)

# Task retrieval
      first_new_task = Task.retrieve(first_list_id, task_ids[0])
      expect(first_new_task.name).to eq(good_task_specs[0][1]['name'])
      expect{Task.retrieve(cantor_list_id, task_ids[0])}.to raise_error(NotFound)
      expect{Task.retrieve(first_list_id, change_hex(task_ids[0]))}.to raise_error(NotFound)
      expect{Task.retrieve(1, task_ids[0])}.to raise_error(BadRequest)
      expect{Task.retrieve(first_list_id, 1)}.to raise_error(BadRequest)

# Task update
      completed_task = Task.complete(first_list_id, first_new_task.id, {'completed' => true})
      expect(completed_task).to eq(first_new_task)
      expect(first_new_task.completed).to equal(true)
      expect{Task.complete(cantor_list_id, first_new_task.id, {'completed' => true})}.to raise_error(NotFound)
      expect{Task.complete(first_list_id, change_hex(first_new_task.id), {'completed' => true})}.to raise_error(NotFound)
      expect{Task.complete(first_list_id, first_new_task.id, {})}.to raise_error(BadRequest)
      expect{Task.complete(first_list_id, first_new_task.id, {'completed' => true, 'wat' => false})}.to raise_error(BadRequest)
      expect{Task.complete(first_list_id, first_new_task.id, [])}.to raise_error(BadRequest)
    end
  end
end

