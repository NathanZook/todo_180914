require 'nztodo_core'

# This is an integration test of the core of the application.

module NZTodo
  RSpec.describe 'core' do
    include SetExampleName

    None = Object.new

    def list_specs_to_data(specs)
      specs.map do |list_spec|
        cause = list_spec.pop
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

        [list_data, cause]
      end
    end

    def transform_task_spec(list_id, name, completed, error, cause)
      data = {'name' => name}
      data['completed'] = completed if completed != None
      [ list_id, data, error, cause ]
    end

    def change_hex(string)
      string.tr('0123456789abcdef', '89abcdef01234567')
    end

    before(:context) do
      [:@lists, :@lists_list].each do |ivar|
        NZTodo::List.instance_variable_get(ivar).clear
      end
    end

    it 'operations demo' do |example|
      @example = example

      good_list_specs = [
        [ 'list 1', None, None, 'no description given' ],
        [ 'list 2 AAA', 'description 2', None, 'no tasks data given' ],
        [ 'list 3 AAA', None, [], 'no description and no tasks given' ],
        [ 'list 4 AAA', 'description 4', [], 'no tasks given' ],
        [ 'list 5 AAA', 'description 5',
          [
            [ 'task 1', None ],
            [ 'task 2', true ],
            [ 'task 3', false ],
          ],
          'full data given',
        ],
      ]
      list_ids = list_specs_to_data(good_list_specs).map do|data, cause|
        set_example_name('creates a list when ' + cause)
        List.create(data)
      end
      first_list_id = list_ids.first.first
      last_list_id = list_ids.last.first

      bad_list_specs = [
        [ None, 'description 6', [], 'list has no name' ],
        [ 1, None, None, 'list has no description' ],
        [ 'list 8', 5, None, 'description is not a string' ],
        [ 'list 9', None, [ [ None, false ] ], 'a task has no name' ],
        [ 'list 10', None, [ [ 'task 5', 1 ] ], 'a task has a completed status which is not a boolean' ],
        [ 'list 11', None, {}, 'the tasks data is not an array' ],
      ]
      list_specs_to_data(bad_list_specs.append([[], 'data is not a hash'])).each do |data, cause|
        set_example_name('refuses to create a list when ' + cause)
        expect{List.create(data)}.to raise_error(BadRequest)
      end

      set_example_name('lists created lists as expected')
      expect(List.list({}).map{|list| list.name}).to eq(good_list_specs.map{|spec| spec[0]})

      set_example_name('lists a limited number of lists with an offset, and only those whose names match search')
      list_params = {'skip' => '1', 'limit' => '2', 'search' => 'AAA'}
      expected_ids = list_ids[2..3].map{|id| id.first}
      expect(List.list(list_params).map{|list| list.id}).to eq(expected_ids)


      set_example_name('retrieves lists by id')
      sample_index = 1
      expect(List.retrieve(list_ids[sample_index].first).name).to eq(good_list_specs[sample_index][0])

      set_example_name('creates lists with default data')
      first_list = List.retrieve(first_list_id)
      expect(first_list.as_json['description']).to eq('')
      expect(first_list.tasks.length).to eq(0)

      set_example_name('creates tasks in lists with default data')
      last_list = List.retrieve(last_list_id)
      expect(last_list.tasks[0].completed).to equal(false)

      set_example_name('creates tasks in lists as directed')
      last_list_task_initial_count = good_list_specs.last.last.length
      expect(last_list.tasks.length).to eq(last_list_task_initial_count)

      good_task_specs = [
        [first_list_id, 'task 7', None, None, 'with no completed data given'],
        [last_list_id, 'task 8', true, None, 'with full data given'],
      ].map{|spec| transform_task_spec(*spec)}
      task_ids = good_task_specs.map do |list_id, data, not_used, cause|
       set_example_name('adds new tasks to existing lists when ' + cause)
       Task.create(list_id, data)
      end

      chars = []
      list_ids.each_with_index do |id, index|
        chars.unshift(change_hex(id.first[-1-index]))
      end
      cantor_list_id = '00000000-0000-0000-0000-' + '0' * (12 - list_ids.length) + chars.join('')
      bad_task_specs = [
        [cantor_list_id, 'task 9', false, NotFound, 'no matching list'],
        [first_list_id, None, false, BadRequest, 'no task_id'],
        [first_list_id, 'task 11', nil, BadRequest, 'no name given for task'],
        [1, 'task 12', false, BadRequest, 'list id is not a uuid'],
      ].map{|spec| transform_task_spec(*spec) }
      bad_task_specs.append([first_list_id, [], BadRequest, 'no task data']).each do |list_id, data, error|
        expect{Task.create(list_id, data)}.to raise_error(error)
      end

      set_example_name('does not create the bad tasks')
      expect(first_list.tasks.length).to eq(1)
      expect(last_list.tasks.length).to eq(last_list_task_initial_count + 1)

# Task retrieval
      set_example_name('retrieves a task by list_id and it\'s own it')
      first_new_task = Task.retrieve(first_list_id, task_ids[0])
      expect(first_new_task.name).to eq(good_task_specs[0][1]['name'])

      [
        [cantor_list_id, task_ids[0], NotFound, 'no list is found'],
        [first_list_id, change_hex(task_ids[0]), NotFound, 'no task is found for the list'],
        [1, task_ids[0], BadRequest, 'list id is not a uuid'],
        [first_list_id, 1, BadRequest, 'task id is not a uuid'],
      ].each do |list_id, task_id, error, cause|
        set_example_name('fails to retrieve a task when ' + cause)
        expect{Task.retrieve(list_id, task_id)}.to raise_error(error)
      end

# Task update
      set_example_name('it updates a task')
      completed_task = Task.complete(first_list_id, first_new_task.id, {'completed' => true})
      expect(completed_task).to eq(first_new_task)
      expect(first_new_task.completed).to equal(true)

      [
        [cantor_list_id, first_new_task.id, {'completed' => true}, NotFound, 'no list is found'],
        [first_list_id, change_hex(first_new_task.id), {'completed' => true}, NotFound, 'no task is found'],
        [first_list_id, first_new_task.id, {}, BadRequest, 'update lacks completed status'],
        [first_list_id, first_new_task.id, {'completed' => true, 'name' => 'renamed'},
            BadRequest, 'attempt to update another key'],
        [first_list_id, first_new_task.id, [], BadRequest, 'update data is not a hash'],
      ].each do |list_id, task_id, completed_data, error, cause|
        set_example_name('fails to update a task when ' + cause)
        expect{Task.complete(list_id, task_id, completed_data)}.to raise_error(error)
      end
      set_example_name('operations demo')
    end
  end
end

