-- Check if admin user exists and verify credentials
SELECT id, username, email, password, role, name 
FROM users 
WHERE username LIKE '%admin%' OR role = 'admin';

-- Show all users to see what accounts exist
SELECT id, username, email, password, role, name 
FROM users 
ORDER BY id;
