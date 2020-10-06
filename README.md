# Dbee Active Record Provider

[![Gem Version](https://badge.fury.io/rb/dbee-active_record.svg)](https://badge.fury.io/rb/dbee-active_record) [![Build Status](https://travis-ci.org/bluemarblepayroll/dbee-active_record.svg?branch=master)](https://travis-ci.org/bluemarblepayroll/dbee-active_record) [![Maintainability](https://api.codeclimate.com/v1/badges/7f74a4e546bebb603cce/maintainability)](https://codeclimate.com/github/bluemarblepayroll/dbee-active_record/maintainability) [![Test Coverage](https://api.codeclimate.com/v1/badges/7f74a4e546bebb603cce/test_coverage)](https://codeclimate.com/github/bluemarblepayroll/dbee-active_record/test_coverage) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Dbee does not ship with a SQL generator by default.  This library plugs into Dbee to provide SQL generation via ActiveRecord.  Technically speaking: this library does not use ActiveRecord for anything except connection information.  All actual SQL generation is performed using Arel.  There is no actual coupling of your domain ActiveRecord subclasses to Dbee.

This library is a plugin for [Dbee](https://github.com/bluemarblepayroll/dbee).  The Dbee repositories README file contains information about how to use the Data Model and Query API's.

## Installation

To install through Rubygems:

````
gem install dbee-active_record
````

You can also add this to your Gemfile:

````
bundle add dbee-active_record
````

## Contributing

### ActiveRecord Dependency

This library supports both ActiveRecord 5 and 6.  Tests are adapted for both versions and should be run against both to ensure compatibility.  By default the latest 6 will be chosen unless overridden. The instructions below explain how to run tests against all supported versions.

### Development Environment Configuration

Basic steps to take to get this repository compiling:

1. Install [Ruby](https://www.ruby-lang.org/en/documentation/installation/) (check dbee-active_record.gemspec for versions supported)
2. Install bundler (gem install bundler)
3. Clone the repository (git clone git@github.com:bluemarblepayroll/dbee-active_record.git)
4. Navigate to the root folder (cd dbee-active_record)
5. Install dependencies (bundle)
6. Install both active_record version 5 and version 6:

      `AR_VERSION=5 bundle install`

      And then:

      `AR_VERSION=6 bundle install`

7. Copy spec/config/database.yaml.ci to spec/config/database.yaml. Customize both Sqlite and MySQL connections per your local environment.

### Running Tests

To execute the test suite run:

```
bundle exec rake spec_all_active_record_versions
```

This will run under all supported ActiveRecord versions. The tests can also be run directly using:

````bash
bundle exec rspec spec --format documentation
````

This will run using the latest ActiveRecord version installed on your system. The environment variable `AR_VERSION` can be set to specify a particular major ActiveRecord version.

Additionally, you can have Guard watch for changes:

````bash
bundle exec guard
````

Also, do not forget to run Rubocop:

````bash
bundle exec rubocop
````

As a convenience, the default rake task runs the specs under all ActiveRecord versions as well as RuboCop:

```
bundle exec rake
```

### Publishing

Note: ensure you have proper authorization before trying to publish new versions.

After code changes have successfully gone through the Pull Request review process then the following steps should be followed for publishing new versions:

1. Merge Pull Request into master
2. Update `lib/dbee-active_record/version.rb` using [semantic versioning](https://semver.org/)
3. Install dependencies: `bundle`
4. Update `CHANGELOG.md` with release notes
5. Commit & push master to remote and ensure CI builds master successfully
6. Run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Code of Conduct

Everyone interacting in this codebase, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/bluemarblepayroll/dbee-active_record/blob/master/CODE_OF_CONDUCT.md).

## License

This project is MIT Licensed.
