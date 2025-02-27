# SQLite migrate

__Database migrations written in make and bash. Inspired by golang-migrate (https://github.com/golang-migrate/migrate)__

* Migrate reads migrations from sources files  and applies them in correct order to the database.
* Use native database CLI tools
* At the moment works with SQLite, could be easy adjusted for PostgreSQL and other DB.
* Minimum dependencies (make, bash, awk, sqlite3)
* Could be used with [Msys2](https://www.msys2.org/) on Windows

## Basic usage

### Getting help

```bash
$ make help
```

### Create new migration file
```bash
$ make migrate/create NAME=migration_name
```
### Migrate up to the revision XXX

```bash
$ make migrate/up/to DB_VERSION=XXX
```

### Migrate up to the latest revision

```bash
$ make migrate/up/all
```

## Migration files

Each migration has an up and down migration. [Why?](https://github.com/golang-migrate/migrate/blob/master/FAQ.md#why-two-separate-files-up-and-down-for-a-migration)

```bash
00001_create_users_table.up.sql
00002_create_users_table.down.sql
```

## See also

 [goalng migrate documentation](https://github.com/golang-migrate/migrate)

