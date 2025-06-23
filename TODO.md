# Carga ORM - Implementation TODO

## 🏗️ Core Architecture

### Database Layer
- [x] **Database Connection Management**
  - [x] SQLite connection pooling
  - [x] Connection configuration and initialization
  - [x] Transaction support (begin, commit, rollback)
  - [x] Connection cleanup and error handling

- [x] **Query Builder Foundation**
  - [x] SQL query builder base class
  - [x] Prepared statement support for security
  - [x] Parameter binding and escaping
  - [x] Query result handling and mapping

### Model Foundation
- [x] **Base Model Class**
  - [x] Model inheritance system (`Model:extend()`)
  - [x] Table name conventions and overrides
  - [x] Field definition and schema mapping
  - [x] Instance creation and initialization

- [x] **Active Record Pattern**
  - [x] Model instance methods (save, update, destroy)
  - [x] Class methods (find, create, where, all)
  - [x] Attribute accessors and mutators
  - [x] Dirty tracking for efficient updates

## 📊 CRUD Operations

### Create Operations
- [x] **Model Creation**
  - [x] `Model:new(attributes)` - build instance
  - [x] `Model:create(attributes)` - create and save
  - [x] `instance:save()` - persist to database
  - [ ] Bulk insert operations

### Read Operations
- [x] **Basic Finders**
  - [x] `Model:find(id)` - find by primary key
  - [x] `Model:find_by(conditions)` - find first match
  - [x] `Model:all()` - get all records
  - [x] `Model:first()` and `Model:last()`

- [x] **Query Builder Chain**
  - [x] `Model:where(conditions)` - add WHERE clause
  - [x] `Model:order(column)` - add ORDER BY
  - [x] `Model:limit(n)` and `Model:offset(n)` - pagination
  - [x] `Model:select(columns)` - column selection
  - [x] `Model:group(columns)` - GROUP BY clause

### Update Operations
- [x] **Instance Updates**
  - [x] `instance:update(attributes)` - update and save
  - [x] `instance:save()` - save changes
  - [x] Dirty attribute tracking
  - [x] Bulk update operations

### Delete Operations
- [x] **Instance Deletion**
  - [x] `instance:destroy()` - delete instance
  - [x] `Model:destroy_all()` - delete all matching
  - [ ] Soft delete support (optional)
  - [ ] Cascade delete handling

## 🔗 Relationships & Associations

### Association Types
- [ ] **belongs_to Associations**
  - [ ] Foreign key management
  - [ ] Lazy loading of parent records
  - [ ] Association caching
  - [ ] Polymorphic belongs_to

- [ ] **has_many Associations**
  - [ ] Collection loading and caching
  - [ ] Association proxy methods
  - [ ] Dependent destroy/nullify options
  - [ ] Through associations (has_many :through)

- [ ] **has_one Associations**
  - [ ] Single record associations
  - [ ] Dependent options
  - [ ] Association building and creation

### N+1 Query Prevention
- [ ] **Eager Loading**
  - [ ] `Model:includes(associations)` - preload associations
  - [ ] Automatic batching of association queries
  - [ ] Deep association loading (nested includes)
  - [ ] Smart query optimization

- [ ] **Association Caching**
  - [ ] In-memory association cache
  - [ ] Cache invalidation strategies
  - [ ] Association proxy objects

## 🔍 Advanced Querying

### Query Builder Features
- [ ] **Complex Conditions**
  - [ ] Raw SQL conditions with parameters
  - [ ] OR conditions and grouping
  - [ ] IN, NOT IN, BETWEEN operators
  - [ ] NULL and NOT NULL checks

- [ ] **Joins and Subqueries**
  - [ ] `Model:joins(table)` - INNER JOIN
  - [ ] LEFT, RIGHT, FULL OUTER joins
  - [ ] Subquery support
  - [ ] Common Table Expressions (CTEs)

- [ ] **Aggregations**
  - [ ] COUNT, SUM, AVG, MIN, MAX
  - [ ] GROUP BY with HAVING clauses
  - [ ] Window functions (if SQLite supports)

### Raw SQL Support
- [ ] **Raw Query Interface**
  - [ ] `Model:query(sql, params)` - execute raw SQL
  - [ ] `Model:execute(sql, params)` - non-SELECT queries
  - [ ] Result mapping to model instances
  - [ ] Named parameter binding

## ✅ Validations

### Built-in Validators
- [x] **Presence Validation**
  - [x] Required field validation
  - [x] Non-empty string validation
  - [x] Custom presence messages

- [x] **Format Validation**
  - [x] Email format validation
  - [ ] URL format validation
  - [ ] Custom regex patterns
  - [ ] Phone number formats

- [x] **Length Validation**
  - [x] Minimum and maximum length
  - [ ] Exact length validation
  - [ ] Character counting options

- [x] **Numeric Validation**
  - [x] Type validation (integer, float)
  - [x] Range validation (min, max)
  - [ ] Positive/negative validation

- [x] **Uniqueness Validation**
  - [x] Database-level uniqueness checks
  - [ ] Scoped uniqueness validation
  - [ ] Case-sensitive/insensitive options

- [x] **Inclusion/Exclusion**
  - [x] Value inclusion in list
  - [ ] Value exclusion from list
  - [ ] Custom inclusion logic

### Custom Validations
- [x] **Validation Framework**
  - [x] `Model:validate()` method override
  - [x] `instance:add_error(field, message)` 
  - [x] `instance:valid()` and `instance:invalid()`
  - [x] Error collection and reporting

- [ ] **Conditional Validations**
  - [ ] Validation conditions (if, unless)
  - [ ] Context-specific validations
  - [ ] Validation groups

## 🔄 Callbacks & Lifecycle

### Callback Types
- [x] **Save Callbacks**
  - [x] `before_save()` and `after_save()`
  - [x] `before_create()` and `after_create()`
  - [x] `before_update()` and `after_update()`

- [ ] **Validation Callbacks**
  - [ ] `before_validation()` and `after_validation()`
  - [ ] Conditional callback execution

- [x] **Destroy Callbacks**
  - [x] `before_destroy()` and `after_destroy()`
  - [ ] Cleanup and cascade operations

### Callback Framework
- [x] **Callback Registration**
  - [x] Method-based callbacks
  - [ ] Proc/function callbacks
  - [ ] Callback chains and ordering

- [ ] **Callback Control**
  - [ ] Callback skipping mechanisms
  - [ ] Conditional callback execution
  - [ ] Callback inheritance

## 🗄️ Database Migrations

### Migration System
- [ ] **Migration Framework**
  - [ ] Migration file structure and naming
  - [ ] Up and down migration methods
  - [ ] Migration versioning and tracking

- [ ] **Schema Operations**
  - [ ] `create_table()` and `drop_table()`
  - [ ] `add_column()` and `remove_column()`
  - [ ] `add_index()` and `remove_index()`
  - [ ] `rename_table()` and `rename_column()`

- [ ] **Migration Runner**
  - [ ] Pending migration detection
  - [ ] Migration execution and rollback
  - [ ] Migration status tracking
  - [ ] Batch migration operations

### Schema Definition
- [ ] **Column Types**
  - [ ] SQLite type mapping (TEXT, INTEGER, REAL, BLOB)
  - [ ] Type validation and conversion
  - [ ] Default value handling
  - [ ] NULL/NOT NULL constraints

- [ ] **Constraints and Indexes**
  - [ ] Primary key definitions
  - [ ] Foreign key constraints
  - [ ] Unique constraints
  - [ ] Check constraints
  - [ ] Index creation and management

## 🧪 Testing Framework

### Test Infrastructure
- [ ] **Test Database**
  - [ ] Separate test database configuration
  - [ ] Test data factories and fixtures
  - [ ] Database cleanup between tests

- [ ] **Model Testing**
  - [ ] Unit tests for all CRUD operations
  - [ ] Association testing
  - [ ] Validation testing
  - [ ] Callback testing

### Test Utilities
- [ ] **Test Helpers**
  - [ ] Model factory methods
  - [ ] Database assertion helpers
  - [ ] Mock and stub utilities
  - [ ] Performance testing tools

## 🚀 Performance & Optimization

### Query Optimization
- [ ] **Query Analysis**
  - [ ] Query logging and profiling
  - [ ] Slow query detection
  - [ ] Query plan analysis

- [ ] **Caching Strategies**
  - [ ] Query result caching
  - [ ] Model instance caching
  - [ ] Association caching
  - [ ] Cache invalidation

### Memory Management
- [ ] **Efficient Loading**
  - [ ] Lazy loading strategies
  - [ ] Batch loading optimizations
  - [ ] Memory-efficient iteration
  - [ ] Connection pooling

## 📚 Documentation & Examples

### API Documentation
- [ ] **Method Documentation**
  - [ ] Complete API reference
  - [ ] Usage examples for all methods
  - [ ] Performance considerations
  - [ ] Best practices guide

### Example Applications
- [ ] **Sample Models**
  - [ ] User/Post/Comment example
  - [ ] E-commerce models (Product, Order, etc.)
  - [ ] Complex association examples
  - [ ] Real-world use cases

## 🔧 Development Tools

### Debugging & Introspection
- [ ] **Model Introspection**
  - [ ] Schema inspection methods
  - [ ] Association introspection
  - [ ] Validation rule inspection
  - [ ] Query debugging tools

### Development Utilities
- [ ] **Console Integration**
  - [ ] Interactive model console
  - [ ] Query testing interface
  - [ ] Database inspection tools
  - [ ] Migration management

---

## Implementation Priority

### Phase 1: Core Foundation (Essential)
1. Database connection and query builder
2. Base model class and Active Record pattern
3. Basic CRUD operations
4. Simple validations and error handling

### Phase 2: Associations (Critical)
1. belongs_to and has_many associations
2. Eager loading and N+1 prevention
3. Association proxy methods
4. Basic relationship management

### Phase 3: Advanced Features (Important)
1. Complex query builder features
2. Callbacks and lifecycle hooks
3. Migration system
4. Advanced validations

### Phase 4: Optimization & Polish (Nice-to-have)
1. Performance optimizations
2. Caching strategies
3. Advanced testing tools
4. Documentation and examples

---

## Success Criteria

- ✅ **Rails-like API**: Familiar interface for Rails developers
- ✅ **No N+1 Queries**: Automatic eager loading and optimization
- ✅ **99% No Raw SQL**: Comprehensive query builder covers most use cases
- ✅ **Performance**: Efficient SQLite operations with minimal overhead
- ✅ **Beautiful Code**: Clean, readable, and maintainable Lua code
- ✅ **Comprehensive Tests**: Full test coverage for all features