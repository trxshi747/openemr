import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  vus: 5,
  duration: '1m',
};

export default function () {
  let res = http.get('http://127.0.0.1:52821/interface/login/login.php');
  check(res, { 'status 200': (r) => r.status === 200 });
  sleep(1);
}
