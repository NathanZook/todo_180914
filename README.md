# Test Project TODO

This is an Todo application inspired by https://app.swaggerhub.com/apis/aweiker/ToDo/1.0.0.

This is a [Sinatra](http://sinatrarb.com/) application (and therefore [Ruby](https://www.ruby-lang.org/en/)).
Ruby gems managed by [Bundler](https://bundler.io/).  Container technology is [Docker](https://www.docker.com/).

It should implement https://app.swaggerhub.com/apis/Zook/simple-to_do_api/1.0.1#/todo/addList.

The differences between the APIs should be as follows:

1. I do not permit the user to specify the id of newly created objects.  This is a DOS risk at least.
1. I return 404 in some cases where an item is missing.
1. I have added get /list/{listId}/task/{taskId} to pull up a particular task.
1. I have changed the response code on item creation to 201, and the response body to the id(s) of the created things.
1. I have added a /test endpoint that will run the specs, and return the results.

Container responds on port 8443 with a self-signed cert.

