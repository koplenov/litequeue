module litequeue

import os
import time

fn test_create_queue() {
	db_path := 'test_queue.db'
	mut queue := litequeue.new(
		path:             db_path
	) or { panic('Failed to create queue: ${err}') }

	queue.conn.close()!
	os.rm(db_path)!
}


fn handler_test(message litequeue.Message) ! {
	return error('AAAA')
}

fn test_create_queue_with_handler() {
	db_path := 'test_queue.db'
	mut queue := litequeue.new(
		path:             db_path
		handler:          handler_test
	) or { panic('Failed to create queue: ${err}') }

	queue.add("test job")!

	time.sleep(time.second)

	queue.conn.close()!
	os.rm(db_path)!
}
