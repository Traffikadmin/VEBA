<?php
// Lightweight health check — returns 200 if PHP is running.
// ALB and ECS use this to determine container health.
http_response_code(200);
header('Content-Type: text/plain');
echo 'ok';
