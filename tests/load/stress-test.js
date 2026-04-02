import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 100 },
    { duration: '2m', target: 300 },
    { duration: '2m', target: 500 },
    { duration: '2m', target: 0 },
  ],
};

export default function () {
  const baseUrl = __ENV.K6_URL || 'http://127.0.0.1:30080';
  let res = http.get(`${baseUrl}/interface/login/login.php`);
  check(res, { 'status 200': (r) => r.status === 200 });
  sleep(1);
}
