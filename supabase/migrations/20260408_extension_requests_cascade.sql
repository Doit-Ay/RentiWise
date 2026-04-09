ALTER TABLE extension_requests 
DROP CONSTRAINT IF EXISTS extension_requests_request_id_fkey;

ALTER TABLE extension_requests 
ADD CONSTRAINT extension_requests_request_id_fkey 
FOREIGN KEY (request_id) REFERENCES requests(id) 
ON DELETE CASCADE;
