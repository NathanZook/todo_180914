ENV['RACK_ENV'] = 'test'

require 'nztodo'
require 'rspec'
require 'rack/test'

RSpec.describe 'TODO app' do
  include Rack::Test::Methods
  include SetExampleName

  def app
    Sinatra::Application
  end

  before(:context) do
    [:@lists, :@lists_list].each do |ivar|
      NZTodo::List.instance_variable_get(ivar).clear
    end
  end

# The state which was built up and tested in core_spec is what we need here.
# It is "safer" this time in that assersions are somewhat more obviously
# proper probes.

  None = Object.new

  def list_specs_to_data(specs)
    specs.map do |list_spec|
      condition = list_spec.pop
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

      [list_data, condition]
    end
  end

  def transform_task_spec(list_id, name, completed, error, condition)
    data = {}
    %w{name completed}.zip([name, completed]).each do |key, value|
      data[key] = value if value != None
    end
    [ list_id, data, error, condition ]
  end

  def change_hex(string)
    string.tr('0123456789abcdef', '89abcdef01234567')
  end

  def parse_response(response, status)
    expect(response.status).to eq(status)
    JSON.load(response.body)
  end

  it 'steals the show' do |example|
    @example = example

    set_example_name('searches the empty set')
    get '/lists'
    expect(last_response).to be_ok
    expect(last_response.body).to eq([].to_json)


    set_example_name('fails to find a missing list')
    get "/list/00000000-0000-0000-0000-000000000000"
    expect(parse_response(last_response, 404)).to eq('List not found.')

    good_list_specs = [
      [ 'list 1', None, None, 'no description or tasks data' ],
      [ 'list 2 AAA', 'description 2', None, 'no tasks data' ],
      [ 'list 3 AAA', None, [], 'no description and empty tasks data' ],
      [ 'list 4 AAA', 'description 4', [], 'empty tasks data' ],
      [ 'list 5 AAA', 'description 5',
        [
          [ 'task 1', None ],
          [ 'task 2', true ],
          [ 'task 3', false ],
        ],
        'with partial tasks data',
      ],
    ]
    list_ids = list_specs_to_data(good_list_specs).map do |data, condition|
      set_example_name('creates when ' + condition)
      post '/lists', data.to_json
      ids_hash = parse_response(last_response, 201)
      [ids_hash['id'], ids_hash['task_ids']]
    end
    first_list_id = list_ids.first.first
    last_list_id = list_ids.last.first

    bad_list_specs = [
      [ None, 'description 6', [], 'missing name' ],
      [ 1, None, None, 'name is not a string' ],
      [ 'list 8', 5, None, 'description is not a string' ],
      [ 'list 9', None, [ [ None, false ] ], 'a task lacks a name' ],
      [ 'list 10', None, [ [ 'task 5', 1 ] ], 'a task has a non-boolean completed status' ],
      [ 'list 11', None, {}, 'tasks data is not a list' ],
    ]
    list_specs_to_data(bad_list_specs.append(['data is not a hash'])).each do |data, condition|
      set_example_name('fails when creating with ' + condition)
      post '/lists', data.to_json
      expect(parse_response(last_response, 400)).to be_a String
    end

    set_example_name('lists lists')
    get '/lists'
    lists = parse_response(last_response, 200)
    expect(lists.map{|list| list['name']}).to eq(good_list_specs.map{|spec| spec[0]})

    set_example_name('lists with parameters')
    list_params = {'skip' => 1, 'limit' => 2, 'search' => 'AAA'}
    expected_ids = list_ids[2..3].map{|id| id.first}
    get '/lists', list_params
    expect(parse_response(last_response, 200).map{|list| list['id']}).to eq(expected_ids)

# List doesn't do the funk

    list_params = {'skip' => 1, 'limit' => 2, 'search' => 'AAA'}
    [
      ['skip', -1, 'skip out of bounds'],
      ['limit', -1, 'limit out of bounds'],
      ['skip', 'abcdefghijkl', 'skip not an integer'],
      ['weird param', 3, 'unexpected paramter found'],
    ].each do |param, value, condition|
      set_example_name('fails to search when ' + condition)
      get '/lists', list_params.merge({param => value})
      expect(parse_response(last_response, 400)).to match(/#{param}/)
    end

    set_example_name('retrieve a list by id')
    sample_index = 1
    get "/list/#{list_ids[sample_index].first}"
    expect(parse_response(last_response, 200)['name']).to eq(good_list_specs[sample_index][0])

    set_example_name('retrieve with a bad id')
    get '/list/1'
    expect(parse_response(last_response, 400)).to eq('Value for list id must be a uuid.')

    set_example_name('sets default values for lists and tasks in lists')
    get "/list/#{first_list_id}"
    first_list = parse_response(last_response, 200)
    expect(first_list['description']).to eq('')
    expect(first_list['tasks'].length).to eq(0)
    get "/list/#{last_list_id}"
    last_list = parse_response(last_response, 200)
    last_list_task_initial_count = good_list_specs.last.last.length
    expect(last_list['tasks'][0]['completed']).to equal(false)
    expect(last_list['tasks'].length).to eq(last_list_task_initial_count)

    good_task_specs = [
      [first_list_id, 'task 7', None, None, 'without completed data'],
      [last_list_id, 'task 8', true, None, 'with completed data'],
    ].map{|spec| transform_task_spec(*spec) }
    task_ids = good_task_specs.map do |list_id, data, not_used, condition|
      set_example_name('adds a task to an existing list ' + condition)
      post "/list/#{list_id}/tasks", data.to_json
      parse_response(last_response, 201)
    end

    chars = []
    list_ids.each_with_index do |id, index|
      chars.unshift(change_hex(id.first[-1-index]))
    end
    cantor_list_id = '00000000-0000-0000-0000-' + '0' * (12 - list_ids.length) + chars.join('')
    bad_task_specs = [
      [cantor_list_id, 'task 9', false, 404, 'list is not found'],
      [first_list_id, None, false, 400, 'task lacks name'],
      [first_list_id, 'task 11', nil, 400, 'task completed status is not boolean'],
      [1, 'task 12', false, 400, 'list id is not a uuid'],
    ].map{|spec| transform_task_spec(*spec) }
    bad_task_specs.append([first_list_id, [], 400, 'task data is not a hash']).each do |list_id, data, error, condition|
      set_example_name('adding a task to a list fails when ' + condition)
      post "/list/#{list_id}/tasks", data.to_json
      message = parse_response(last_response, error)
      if error == 404
        expect(message).to eq('List not found.')
      else
        expect(message).to match(/^Value|^Missing/)
      end
    end

    set_example_name('tasks add (and not) as expected')
    get "/list/#{first_list_id}"
    first_list_tasks = parse_response(last_response, 200)['tasks']
    expect(first_list_tasks.length).to eq(1)
    expect(first_list_tasks[-1]['id']).to eq(task_ids[0])
    get "/list/#{last_list_id}"
    last_list_tasks = parse_response(last_response, 200)['tasks']
    expect(last_list_tasks.length).to eq(last_list_task_initial_count + 1)
    expect(last_list_tasks[-1]['id']).to eq(task_ids[1])

    set_example_name('task retrieval')
    get "/list/#{first_list_id}/task/#{task_ids[0]}"
    expect(parse_response(last_response, 200)['name']).to eq(good_task_specs[0][1]['name'])

    good_retrieval_data = [first_list_id, task_ids[0]]
    [
      [0, cantor_list_id, 404, 'list missing'],
      [1, change_hex(task_ids[0]), 404, 'task missing from list'],
      [0, 1, 400, 'list id is not a uuid'],
      [1, 1, 400, 'task id is not a uuid'],
    ].each do |index, value, error, condition|
      set_example_name('task retrieval fails when ' + condition)
      data = good_retrieval_data.dup
      data[index] = value
      get "/list/#{data[0]}/task/#{data[1]}"
      message = parse_response(last_response, error)
      if error == 404
        expect(message).to match(/not found\.$/)
      else
        expect(message).to match(/uuid\.$/)
      end
    end

    set_example_name('updating a task')
    good_update_data = [first_list_id, task_ids[0], {'completed' => true}]
    post "/list/#{good_update_data[0]}/task/#{good_update_data[1]}/complete", good_update_data[2].to_json
    expect(parse_response(last_response, 200)['completed']).to equal(true)

    [
      [0, cantor_list_id, 404, 'list not found'],
      [1, change_hex(task_ids[0]), 404, 'task not found in list'],
      [2, {}, 400, 'no completed data'],
      [2, {'completed' => true, 'name' => 'rename'}, 400, 'completed data has extra key'],
      [2, [], 400, 'completed data is not a hash'],
    ].each do |index, value, error, condition|
      set_example_name('updating a task fails when ' + condition)
      data = good_update_data.dup
      data[index] = value
      post "/list/#{data[0]}/task/#{data[1]}/complete", data[2].to_json
      message = parse_response(last_response, error)
      if error == 404
        expect(message).to match(/not found\.$/)
      end
    end

    %i{get post head put delete options patch}.each do |verb|
      set_example_name('hits on weird urls with verb ' + verb.to_s)
      send(verb, '/a/weird/url/i/thing', {'some' => 'junk'})
      expect(parse_response(last_response, 404)).to be_a(verb == :head ? nil.class : String)
    end

    set_example_name('steals the show')
  end
end

