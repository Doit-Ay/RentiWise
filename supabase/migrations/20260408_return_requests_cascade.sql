ALTER TABLE return_requests 
DROP CONSTRAINT IF EXISTS return_requests_request_id_fkey;

ALTER TABLE return_requests 
ADD CONSTRAINT return_requests_request_id_fkey 
FOREIGN KEY (request_id) REFERENCES requests(id) 
ON DELETE CASCADE;
