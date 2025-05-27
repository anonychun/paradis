<p align="center">
  <img width="300" src="https://github.com/user-attachments/assets/338efbcb-e1e4-4bce-8016-4f9c5ebaeb6b" alt="Paradis logo">
</p>

<h1 align="center">
  PARADIS
</h1>

This project is a Rails application template designed to streamline the setup of new Rails projects. It includes predefined configurations, routes, and utility modules to help you get started quickly.

I created this template after being inspired by ecosystems outside of Rails. Observing how other frameworks and languages structure their projects and provide out-of-the-box solutions for common tasks motivated me to bring similar conveniences to the Rails community.

## Installation

Create a new Rails application using the template by running the following command in your terminal:

```bash
rails new app \
  --javascript esbuild \
  --css tailwind \
  --skip-rubocop \
  -m https://raw.githubusercontent.com/anonychun/paradis/main/template.rb
```

This command will create a new Rails application named `app` and apply the Paradis template to it. The `--skip-rubocop` option is used to skip the default RuboCop configuration, as Paradis uses `standard` for linting and formatting.

## Basic Usage

Paradis is just combination of built-in Rails features and some additional gems. Here are some of the features that you can use:

#### Blueprint Layer

Blueprint objects are used to represent your models in a way that can be easily serialized into JSON. You can define an blueprint object by inheriting from `ApplicationBlueprint` powered by `blueprinter` gem and expose the attributes you want to include in the JSON response.

Be aware that you can also expose associations and nested entities, avoid exposing sensitive and unnecessary attributes.

```ruby
class ArticleBlueprint < ApplicationBlueprint
  field :title
  field :content
  association :author, blueprint: AuthorBlueprint
end
```

If you're using Active Storage, you can expose the attachment URLs by using the other defined blueprint that only exposes the URL.

```ruby
class Article < ApplicationRecord
  has_one_attached :thumbnail_file
  has_many_attached :content_files
end

class BlobBlueprint < ApplicationBlueprint
  field :url
end

class ArticleBlueprint < ApplicationBlueprint
  field :title
  field :content
  field :thumbnail_file, blueprint: BlobBlueprint
  field :content_files, blueprint: BlobBlueprint
end
```

#### Standardize API Response

Use `present` method in `controller` or `view` to standardize the API response. The `present` method will automatically wrap the response in a JSON object with the following structure:

if the status code is indicating an error the `errors` field will be containing the error messages otherwise null.

```json
{
  "ok": true,
  "meta": null,
  "data": {
    "article": {
      "id": "0196a944-0603-7464-8363-99b2d0ef18f4",
      "title": "Hello world",
      "content": "This is the content of the article"
    }
  },
  "errors": null
}
```

Example of using `present` in a controller or view:

```ruby
# app/controllers/api/v1/hello_controller.rb
class Api::V1::HelloController < Api::V1Controller
  def greeting
    @to = "world"
  end
end

# app/views/api/v1/hello/greeting.json.jbuilder
present json do
  json.hello @to
end
```

Or return a JSON response directly in the controller.

```ruby
class Api::V1::HelloController < Api::V1Controller
  def greeting
    present json: {
      hello: "world"
    }
  end
end
```

Both methods will return the same JSON response.

```json
{
  "ok": true,
  "meta": null,
  "data": {
    "hello": "world"
  },
  "errors": null
}
```

You can also use `present_meta` in controller to include meta information in the response.

```ruby
class Api::V1::HelloController < Api::V1Controller
  def greeting
    present_meta :weather, "sunny"

    present json: {
      hello: "world"
    }
  end
end
```

```json
{
  "ok": true,
  "meta": {
    "weather": "sunny"
  },
  "data": {
    "hello": "world"
  },
  "errors": null
}
```

#### Error Handling

Send error response using the `error!` method if you're on a controller and raise `ApiError` if you're outside of the controller.

If you're sending a string as error it will automatically be converted to an object with the key `message`.

```ruby
class Api::V1::ArticleController < Api::V1Controller
  def restricted
    error!("You are not authorized to access this resource", status: :unauthorized)
  end
end
```

```ruby
def get_article(id)
  article = Article.find_by(id: id)
  raise ApiError.new("Article not found", :not_found) unless article.present?

  article
end
```

When you want to send a manual parameter validation error, you can use the `param_error!` method.

```ruby
param_error!(:email, "must be filled", "must be a valid email")
```

#### Parameters Validation

You can validate parameters using the `params.validate!` method. This method uses the `dry-schema` gem to validate parameters based on the rules you define.

```ruby
class Api::V1::ArticleController < Api::V1Controller
  def create
    params.validate! do
      required(:title).filled(:string)
      required(:content).filled(:string)
    end

    @article = Article.create!(title: params[:title], content: params[:content])
  end
end
```

When validation fails, the response will properly map the error messages with the corresponding fields.

```json
{
  "ok": false,
  "meta": null,
  "data": null,
  "errors": {
    "params": {
      "email": ["must be filled"],
      "password": ["must be filled"]
    }
  }
}
```

#### Pagination

Use the `paginate` method to paginate the records. The `paginate` method automatically validate and uses the `page`, `per_page`, `start_date` and `end_date` parameters from the request to paginate the records.

```ruby
class Api::V1::ArticleController < Api::V1Controller
  def index
    articles = paginate Article.order(id: :desc)
    present json: ArticleBlueprint.represent(articles)
  end
end
```

The result will send the paginated information in the meta section of the response.

```json
{
  "ok": true,
  "meta": {
    "pagination": {
      "page": 1,
      "per_page": 10,
      "total": 50
    }
  },
  "data": [],
  "errors": null
}
```
