import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  noConnectionReuse: true,
  stages: [
    { duration: '2m', target: 100 },
    { duration: '2m', target: 300 },
    { duration: '2m', target: 500 },
    { duration: '2m', target: 0 },
  ],
};

export default function () {
  let res = http.get('http://localhost:30007/interface/login/login.php');
  check(res, { 'status 200': (r) => r.status === 200 });
  sleep(1);
}
