### install:
v install koplenov.litequeue

## usage

### simple usage in queue_test.v file

### veb usage:

```vlang
module main

import veb
import db.sqlite
import litequeue
import time

pub struct Context {
	veb.Context
}

pub struct App {
pub:
	db sqlite.DB
mut:
	queue litequeue.Queue
}

pub fn (app &App) index(mut ctx Context) veb.Result {
	return ctx.text('some index')
}

// http://localhost:8080/add_job
pub fn (mut app App) add_job(mut ctx Context) veb.Result {
	app.queue.add('add job') or { return ctx.text('error! not added') }
	return ctx.text('ok! added')
}

// http://localhost:8080/list_finished
pub fn (mut app App) list_finished(mut ctx Context) veb.Result {
	return ctx.text(app.queue.list_of(.done).str())
}

fn main() {
	db := sqlite.connect('queue.sqlite3') or { panic(err) }
	mut queue := litequeue.new(
		db:      db
		handler: queue_function
	) or { panic('Failed to create queue: ${err}') }

	mut app := &App{
		db:    db
		queue: queue
	}

	veb.run[App, Context](mut app, 8080)
}

fn queue_function(message litequeue.Message) ! {
	time.sleep(time.second)
	println('handled function message!: ' + message.str())
}

```
