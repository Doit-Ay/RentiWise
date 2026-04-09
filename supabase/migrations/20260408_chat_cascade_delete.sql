ALTER TABLE chat_conversations
DROP CONSTRAINT IF EXISTS chat_conversations_item_id_fkey;

ALTER TABLE chat_conversations
ADD CONSTRAINT chat_conversations_item_id_fkey 
FOREIGN KEY (item_id) REFERENCES items(id) 
ON DELETE CASCADE;
