<p align="center">
  <img width="400" src="https://github.com/user-attachments/assets/338efbcb-e1e4-4bce-8016-4f9c5ebaeb6b" alt="Paradis logo">
</p>

# PARADIS

This project is a Rails application template designed to streamline the setup of new Rails projects. It includes predefined configurations, routes, and utility modules to help you get started quickly.

I created this template after being inspired by ecosystems outside of Rails. Observing how other frameworks and languages structure their projects and provide out-of-the-box solutions for common tasks motivated me to bring similar conveniences to the Rails community.

## Installation

There are multiple templates available to choose from:

- API

  ```bash
  rails new app \
    --main \
    --api \
    --skip-kamal \
    --skip-thruster \
    --skip-brakeman \
    -m https://raw.githubusercontent.com/anonychun/paradis/main/api_template.rb
  ```

- Inertia

  ```bash
  # coming soon
  ```

## Basic Usage

Paradis is just combination of built-in Rails features and some additional gems. Here are some of the features that you can use:

### Base

Features that are available in all templates.

- Use `rapidjson` for JSON serialization.
- `ULID` as the primary key for SQLite database and `UUIDv7` for other databases.
- Fix datetime when using PostgreSQL database to use `timestamptz` for time zone support.
- Setup `mission_control-jobs` for monitoring background jobs.
- Clear `log` in local environment everytime starting the app.

#### Parameters Validation

You can validate parameters using the `params.validate!` method. This method uses the `dry-schema` gem to validate parameters based on the rules you define.

```ruby
class Api::V1::ArticleController < Api::V1Controller
  def create
    params.validate! do
      required(:title).filled(:string)
      required(:content).filled(:string)
    end

    article = Article.create!(title: params[:title], content: params[:content])
    render_json data: ArticleEntity.represent(article), status: 201
  end
end
```

#### Service Layer

Service object is a pattern that can help you separate business logic from controllers and models, making your code more modular and easier to test and avoid fat models and controllers.

Simply create a new service object by inheriting from `ApplicationService` and define a `call` method. You can then call the service object using the `call` class method.

```ruby
class Article::TopFiveService < ApplicationService
  def initialize(category:)
    @category = category
  end

  def call
    # your logic
  end
end

Article::TopFiveService.call(category: "technology")
```

#### Entity Layer

Entity objects are used to represent your models in a way that can be easily serialized into JSON. You can define an entity object by inheriting from `ApplicationEntity` powered by `grape-entity` gem and expose the attributes you want to include in the JSON response.

Be aware that you can also expose associations and nested entities, avoid exposing sensitive and unnecessary attributes, use the `if` option to conditionally expose attributes.

> [!WARNING]
> The `ApplicationEntity` automatically exposes the `id`, `created_at`, and `updated_at` attributes of the model.

```ruby
class ArticleEntity < ApplicationEntity
  expose :title
  expose :content
  expose :author, using: AuthorEntity, if: lambda { |object|
    object.association(:author).loaded?
  }
end
```

If you're using Active Storage, you can expose the attachment URLs when the association is loaded.

```ruby
class Article < ApplicationRecord
  has_one_attached :thumbnail_file
  has_many_attached :content_files
end

class BlobEntity < Grape::Entity
  expose :url
end

class ArticleEntity < ApplicationEntity
  expose :title
  expose :content
  expose :thumbnail_file, using: BlobEntity, if: lambda { |object|
    object.association(:thumbnail_file_blob).loaded?
  }
  expose :content_files, using: BlobEntity, if: lambda { |object|
    object.association(:content_files_blobs).loaded?
  }
end
```

### API

Features that are available in the API template.

- Predefined `routes` and `controller` for versioning.
- Handle `exception` in application and send a proper response.

JSON structure for the response looks like this:

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

#### Send Response

You can use the `render_json` method to send a JSON response.

```ruby
class Api::V1::ArticleController < Api::V1Controller
  def index
    articles = Article.all
    render_json data: ArticleEntity.represent(articles)
  end

  def show
    article = Article.find(params[:id])
    recommendations = Article::TopFiveService.call(category: article.category)

    render_json data: {
      article: ArticleEntity.represent(article),
      recommendations: ArticleEntity.represent(recommendations)
    }
  end
end
```

You can also build a response using the `present_meta` and `present` method and send it using the `render_json` method.

```ruby
class Api::V1::ArticleController < Api::V1Controller
  def show
    present_meta :ads, true

    present :article, Article.find(params[:id])
    present :latest_articles, Article.order(created_at: :desc).limit(5)

    render_json
  end
end
```

Send error response using the `error!` method if you're on a controller and raise `ApiError` if you're outside of the controller.

If you're sending a string as error it will automatically be converted to an object with the key `message`.

```ruby
class Api::V1::ArticleController < Api::V1Controller
  def restricted
    error!("You are not authorized to access this resource", status: 403)
  end
end
```

```ruby
def get_article(id)
  article = Article.find_by(id: id)
  raise ApiError.new("Article not found", status: 404) if article.nil?

  article
end
```

When you want to send a manual parameter validation error, you can use the `param_error!` method.

```ruby
param_error!(:email, "must be filled", "must be a valid email")
```

#### Pagination

Use the `paginate` method to paginate the records. The `paginate` method automatically validate and uses the `page`, `per_page`, `start_date` and `end_date` parameters from the request to paginate the records.

```ruby
class Api::V1::ArticleController < Api::V1Controller
  def index
    articles = paginate Article.order(created_at: :desc)
    render_json data: ArticleEntity.represent(articles)
  end
end
```

### Inertia

Coming soon.
