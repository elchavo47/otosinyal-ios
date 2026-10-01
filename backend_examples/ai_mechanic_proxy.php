<?php
// OTOSINYAL AI Mechanic proxy example.
// Keep OPENAI_API_KEY on the server. Never place it in the Flutter app.
header('Content-Type: application/json; charset=utf-8');
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'POST required']);
    exit;
}

$apiKey = getenv('OPENAI_API_KEY');
$model = getenv('OPENAI_MODEL') ?: 'gpt-5.6-luna';
if (!$apiKey) {
    http_response_code(500);
    echo json_encode(['error' => 'OPENAI_API_KEY is not configured on server']);
    exit;
}

$raw = file_get_contents('php://input');
$input = json_decode($raw, true);
$prompt = trim((string)($input['prompt'] ?? ''));
if ($prompt === '') {
    http_response_code(400);
    echo json_encode(['error' => 'prompt is required']);
    exit;
}
if (strlen($prompt) > 60000) {
    http_response_code(413);
    echo json_encode(['error' => 'prompt too large']);
    exit;
}

$payload = json_encode([
    'model' => $model,
    'input' => $prompt,
    'reasoning' => ['effort' => 'low'],
]);

$ch = curl_init('https://api.openai.com/v1/responses');
curl_setopt_array($ch, [
    CURLOPT_POST => true,
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_CONNECTTIMEOUT => 12,
    CURLOPT_TIMEOUT => 60,
    CURLOPT_HTTPHEADER => [
        'Authorization: Bearer ' . $apiKey,
        'Content-Type: application/json',
    ],
    CURLOPT_POSTFIELDS => $payload,
]);
$body = curl_exec($ch);
$status = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
$error = curl_error($ch);
curl_close($ch);

if ($body === false || $error) {
    http_response_code(502);
    echo json_encode(['error' => 'OpenAI connection failed']);
    exit;
}
$data = json_decode($body, true);
if ($status < 200 || $status >= 300) {
    http_response_code(502);
    echo json_encode(['error' => 'OpenAI request failed', 'upstream_status' => $status]);
    exit;
}

$answer = '';
if (!empty($data['output_text']) && is_string($data['output_text'])) {
    $answer = $data['output_text'];
} elseif (!empty($data['output']) && is_array($data['output'])) {
    foreach ($data['output'] as $item) {
        if (($item['type'] ?? '') !== 'message') continue;
        foreach (($item['content'] ?? []) as $content) {
            if (($content['type'] ?? '') === 'output_text' && isset($content['text'])) {
                $answer .= (string)$content['text'];
            }
        }
    }
}
if (trim($answer) === '') {
    http_response_code(502);
    echo json_encode(['error' => 'OpenAI returned no text']);
    exit;
}

echo json_encode(['answer' => trim($answer), 'model' => $model], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
