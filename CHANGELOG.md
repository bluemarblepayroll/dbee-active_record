# 2.1.0 (TBD)

### Additions:

* Implemented Dbee::Query::Field#aggregator
* Implemented Dbee::Query::Field#filters

### Changes:

* Bumped minimum Ruby version to 2.5

# 2.0.4 (February 13th, 2020)

* use Arel#in for Equal filters when there is more than one value
* use Arel#not_in for NotEqual filters when there are is than one value

# 2.0.3 (January 7th, 2020)

* Added/tested support for Dbee 2.0.3
* Added support for Ruby 2.6.5

# 2.0.2 (November 7th, 2019)

* Added/tested support for Dbee 2.0.2
* Added support for Ruby 2.3.8

# 2.0.1 (October 25th, 2019)

* Development dependency updates.

# 2.0.0 (September 3rd, 2019)

* Only support Dbee version 2.0.0 and above

# 1.2.0 (August 29th, 2019)

* Add support for Dbee partitioners
* Only support Dbee version 1.2.0 and above

# 1.1.0 (August 27th, 2019)

* Only support Dbee version 1.1.0 and above

# 1.0.4 (August 27th, 2019)

* Added support for Dbee static constraint against the parent part of an association.

# 1.0.3 (August 27th, 2019)

* Raises MissingConstraintError when trying to join to a table without at least one constraint.

# 1.0.2 (August 26th, 2019)

* Only support Dbee version 1.0.2 and above
* Added support and test matrices for ActiveRecord 6

# 1.0.1 (August 26th, 2019)

* Only support Dbee version 1.0.1 and above

# 1.0.0 (August 23rd, 2019)

Initial release, stable public API.

# 1.0.0-alpha (August 20th, 2019)

Added initial implementation.

# 0.0.1 (August 18th, 2019)

Initial library shell published.
