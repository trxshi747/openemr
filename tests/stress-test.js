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

const BASE_URL = 'http://127.0.0.1:53877';

export default function () {
  let res1 = http.get(`${BASE_URL}/`);
  check(res1, { 'status 200': (r) => r.status === 200 || r.status === 302 || r.status === 401 });

  let res2 = http.get(`${BASE_URL}/interface/login/login.php`);
  check(res2, { 'status 200': (r) => r.status === 200 || r.status === 302 || r.status === 401 });

  let res3 = http.get(`${BASE_URL}/apis/default/api/facility`);
  check(res3, { 'status 200': (r) => r.status === 200 || r.status === 302 || r.status === 401 });

  sleep(1);
}
