#
# Copyright ad-pro
# https://github.com/ad-pro/
#
# 2025-02-27
#
# Use sqlite3 command-line utility to create database migrations
# Inspired by: https://github.com/golang-migrate/migrate
#
# This code is released under the terms of the MIT license. See the file LICENSE for details.
#

# Directories
ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
DB_PATH  := $(ROOT_DIR)/db
MIGRATIONS_PATH := $(ROOT_DIR)/migrations

# Database Configuration
DB_FILE ?= $(DB_PATH)/test_migration.sqlite
SQL_CMD := /usr/bin/sqlite3 $(DB_FILE)

# Default Migration Naming
DATE := $(shell date +%Y.%m.%d-%H%M)
NAME ?= test_migration

# Declare default database version for migration scripts
export DB_VERSION ?= 1

#####################################
# Functions for migration operations
#####################################

ensure_not_dirty = \
	@res=$$($(SQL_CMD) "SELECT COALESCE(dirty, 0) FROM schema_migrations;");  \
	if [ "$$res" = "1" ]; then \
		echo "Error: Migration is dirty"; \
		exit 1; \
	fi

get_version = \
	$(SQL_CMD) "SELECT COALESCE(version, 0) FROM schema_migrations;"

set_dirty = \
	$(SQL_CMD) "UPDATE schema_migrations SET dirty = 1;"

unset_dirty = \
	$(SQL_CMD) "UPDATE schema_migrations SET dirty = 0;"

format_version = \
	$(SQL_CMD) "SELECT FORMAT('%05u', version) FROM schema_migrations;"

#############################
# Targets
#############################

.PHONY: all \
	help \
	help/all \
	migrate/create \
	migrate/up/all \
	migrate/down/all \
	migrate/up/1 \
	migrate/down/1 \
	migrate/up/to \
	migrate/down/to \
	migrate/version \
	migrate/dto \
	migrate/force \
	dummy

all:: help

## Create a new migration file: NAME=migration_name
migrate/create::
	@res=$$($(call format_version)); \
	touch "$(MIGRATIONS_PATH)/$${res}_$(NAME).up.sql"; \
	touch "$(MIGRATIONS_PATH)/$${res}_$(NAME).down.sql"; \

## Initialize the database: [DB_FILE=database_file]
create/db::
	@echo "Creating database: $(DB_FILE)"
	@$(SQL_CMD) "CREATE TABLE IF NOT EXISTS schema_migrations (version UINT64, dirty BOOL);"
	@$(SQL_CMD) "CREATE UNIQUE INDEX IF NOT EXISTS schema_migrations_version_u ON schema_migrations (version);"
	@$(SQL_CMD) "INSERT INTO schema_migrations (version, dirty) VALUES (0, 0);"
	@echo "Database $(DB_FILE) created OK"

## Remove the database
drop/db::
	rm -f $(DB_FILE)

## Print database file path
get/db/path::
	@echo $(DB_FILE)

## ---

.ONESHELL:
## List available migrations (only UP is shown)
migrate/ls::
	@cd $(MIGRATIONS_PATH)
	ls *.up.sql -1

## Print current migration version
migrate/version::
	@$(call get_version)

## Force migration version without execution: DB_VERSION=X
migrate/force::
	@$(call unset_dirty);
	$(SQL_CMD) "UPDATE schema_migrations SET version = $(DB_VERSION)"

## ---

.ONESHELL:
## Migrate up by one version
migrate/up/1::
	@$(call ensure_not_dirty)
	current_version=$$($(call format_version))
	echo "Migrating up 1 step. Current version: $$current_version"
	find $(MIGRATIONS_PATH) -type f -name "*up.sql" | sort |
	while read file; do 
		new_version=$$(basename $$file | grep -Eo '^[0-9]+')
		if [ $$new_version -gt $$current_version ]; then
			echo "Applying migration: $$file (New Version: $$new_version)"
			$(SQL_CMD) ".read $$file"
			$(SQL_CMD) "UPDATE schema_migrations SET version = $$new_version"
			break
		fi
	done
	echo "Migration complete"


.ONESHELL:
## Migrate down by one version
migrate/down/1::
	@$(call ensure_not_dirty)
	current_version=$$($(call format_version))
	echo "Migrating down 1 step. Current version: $$current_version"
	flag_step_done=0
	find $(MIGRATIONS_PATH) -type f -name "*down.sql" | sort -r |
	while read file; do 
		new_version=$$(basename $$file | grep -Eo '^[0-9]+')
		delta=$$(($$current_version - $$new_version))
		if [ $$flag_step_done -eq 1 ]; then
			echo "Updating to previous migration version: $$new_version"
			$(SQL_CMD) "UPDATE schema_migrations SET version = $$new_version"
			break
		fi
		if [ $$delta -ge 0 ]; then
			prev_version=$$(($$new_version - 1))
			echo "Reverting migration: $$file (Previous version: $$prev_version)"
			$(SQL_CMD) ".read $$file"
			$(SQL_CMD) "UPDATE schema_migrations SET version = $$prev_version"
			flag_step_done=1
			continue
		fi
	done
	echo "Migration complete"

.ONESHELL:
## Migrate up to the latest available version
migrate/up/all::
	@$(call ensure_not_dirty)
	current_version=$$($(call format_version))
	echo "Migrating up to latest version. Current Version: $$current_version"
	find $(MIGRATIONS_PATH) -type f -name "*up.sql" | sort |
	while read file; do 
		new_version=$$(basename $$file | grep -Eo '^[0-9]+')
		if [ $$new_version -gt $$current_version ]; then
			echo "Applying migration: $$file"
			$(SQL_CMD) ".read $$file"
			$(SQL_CMD) "UPDATE schema_migrations SET version = $$new_version"
		fi
	done
	echo "Migration complete"

## Migrate down all versions (full rollback)
migrate/down/all::
	@$(call ensure_not_dirty)
	current_version=$$($(call format_version))
	echo "Rolling back all migrations. Current Version: $$current_version"
	find $(MIGRATIONS_PATH) -type f -name "*down.sql" | sort -r |
	while read file; do
		new_version=$$(basename $$file | grep -Eo '^[0-9]+')
		if [ $$new_version -le $$current_version ]; then
			prev_version=$$(($$new_version - 1))
			echo "Rolling back: $$file (Reverting to: $$prev_version)"
			$(SQL_CMD) ".read $$file"
			$(SQL_CMD) "UPDATE schema_migrations SET version = $$prev_version"
		fi
	done
	echo "All migrations rolled back"

.ONESHELL:
## Migrate up to a specific version: DB_VERSION=X
migrate/up/to::
	@$(call ensure_not_dirty)
	current_version=$$($(call format_version))
	echo "Migrating up to: $$DB_VERSION (Current Version: $$current_version)"
	find $(MIGRATIONS_PATH) -type f -name "*up.sql" | sort |
	while read file; do
		new_version=$$(basename $$file | grep -Eo '^[0-9]+')
		if [ $$new_version -le $$current_version ]; then
			continue
		fi
		if [ $$new_version -le $$DB_VERSION ]; then
			echo "Applying migration: $$file"
			$(SQL_CMD) ".read $$file"
			$(SQL_CMD) "UPDATE schema_migrations SET version = $$new_version"
		else
			break
		fi
	done
	echo "Migration complete"

.ONESHELL:
## Migrate down to a specific version: DB_VERSION=X
migrate/down/to::
	@$(call ensure_not_dirty)
	current_version=$$($(call format_version))
	echo "Migrating down to: $$DB_VERSION (Current Version: $$current_version)"
	find $(MIGRATIONS_PATH) -type f -name "*down.sql" | sort -r |
	while read file; do
		new_version=$$(basename $$file | grep -Eo '^[0-9]+')
		if [ $$new_version -gt $$current_version ]; then
			continue
		fi
		if [ $$new_version -le $$DB_VERSION ]; then
			$(SQL_CMD) "UPDATE schema_migrations SET version = $$new_version"
			break
		fi
		echo "Reverting migration: $$file"
		prev_version=$$(($$new_version -1))
		$(SQL_CMD) ".read $$file"
		$(SQL_CMD) "UPDATE schema_migrations SET version = $$prev_version"
	done
	echo "Migration complete"

## ---

dummy::
	@echo "dummy"

## Print this help
help::
	@awk '/^## ---/ {c=substr($$0,7); print c ":"; c=0; next} /^## /{c=substr($$0,3);next}c&&/^[[:alpha:]][[:alnum:]_/-]+:/{print substr($$1,1,index($$1,":")),c}1{c=0}' $(MAKEFILE_LIST) | column -s: -t -W 2,3 -o " "

## Print extended help. Show all possible targets
help/all:: help
	@awk '/^## /{c=substr($$0,3);next}c&&/^[[:alpha:]][[:alnum:]_/-]+:/{print substr($$1,1,index($$1,":")),c}1{c=0}' $(MAKEFILE_LIST) | column -s: -t -W 2,3 -o " "
	@echo ""
	@echo "Other Targers:"
	@echo ""
	@awk '/^## ---/ {c=substr($$0,8); print c ":"; c=0; next} /^### /{c=substr($$0,4);next}c&&/^[[:alpha:]][[:alnum:]_/-]+:/{print substr($$1,1,index($$1,":")),c}1{c=0}' $(MAKEFILE_LIST) | column -s: -t -W 2,3 -o " "
