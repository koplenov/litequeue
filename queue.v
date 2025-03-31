module litequeue

import time
import db.sqlite

pub enum MessageStatus as u8 {
	ready
	locked
	done
	failed
}

// Struct Message
pub struct Message {
pub mut:
	data       string
	message_id int @[primary; sql: serial]
	status     MessageStatus
	in_time    time.Time @[default: 'CURRENT_TIME']
	lock_time  ?time.Time
	done_time  ?time.Time
}

// Struct Queue
pub struct Queue {
pub mut:
	conn &sqlite.DB
}

fn C.sqlite3_config(int)

// Function NewQueue (Constructor)
pub struct Queue_config {
pub:
	path             string
	db               ?sqlite.DB      @[omitempty]
	handler          ?fn (Message) ! @[omitempty]
	pooling_interval i64 = time.second
}

pub fn new(config Queue_config) !Queue {
	C.sqlite3_config(3)

	// use exist db connection or create file self
	mut conn := if db := config.db {
		db
	} else {
		sqlite.connect(config.path) or { return error('Failed to connect to database: ${err}') }
	}
	conn.busy_timeout(10 * 60_000)

	mut queue := Queue{
		conn: &conn
	}

	queue.setup() or { return error('Setup Failed: ${err}') }

	if handler := config.handler {
		println('taked handler function!')
		runner := fn [mut queue, config, handler] () {
			for {
				if message := queue.take() {
					handler(message) or {
						queue.mark_fail(message.message_id)
						println('[queue][fail][${message.message_id}]')
						continue
					}
					queue.mark_done(message.message_id)
					println('[queue][done][${message.message_id}]')
				} else {
					// println('[queue][pooling]')
					time.sleep(config.pooling_interval)
				}
			}
		}
		spawn runner()
	}

	return queue
}

// Method setup
fn (mut self Queue) setup() ! {
	sql self.conn {
		create table Message
	}!
}

// Method put
pub fn (mut self Queue) add(data string) !Message {
	message := Message{
		data:    data
		status:  MessageStatus.ready
		in_time: time.now()
	}

	sql self.conn {
		insert message into Message
	} or { return err }
	return message
}

// Method pop_transaction
pub fn (mut self Queue) take() ?Message {
	now := time.now()

	messages := sql self.conn {
		select from Message where status == MessageStatus.ready order by message_id limit 1
	} or { return none }

	if messages.len == 0 {
		return none
	}

	message := messages.first()

	sql self.conn {
		update Message set status = MessageStatus.locked where message_id == message.message_id
		update Message set lock_time = now where message_id == message.message_id
	} or { panic(err) }
	return message
}

// Return all the tasks in gived state.
pub fn (mut self Queue) list_of(status MessageStatus) []Message {
	list_failed := sql self.conn {
		select from Message where status == status
	} or { panic(err) }
	return list_failed
}

// Mark a locked message as free again.
pub fn (mut self Queue) mark_fail(message_id int) {
	sql self.conn {
		update Message set status = MessageStatus.failed where message_id == message_id
		update Message set done_time = none where message_id == message_id
	} or { panic(err) }
}

// Method pop_transaction
pub fn (mut self Queue) mark_done(message_id int) {
	now := time.now()

	sql self.conn {
		update Message set status = MessageStatus.done where message_id == message_id
		update Message set done_time = now where message_id == message_id
	} or { panic(err) }
}

// Mark a locked message as free again.
pub fn (mut self Queue) len() int {
	count := sql self.conn {
		select count from Message
	} or { panic(err) }
	return count
}

pub fn (mut self Queue) next() ?Message {
	return self.take()
}

// Return all the tasks in gived state.
pub fn (mut self Queue) close()! {
	self.conn.close()!
}
