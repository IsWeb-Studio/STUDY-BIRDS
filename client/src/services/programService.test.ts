import { afterEach, expect, it, vi } from 'vitest';
import axios from 'axios';
vi.mock('../lib/api', () => ({ api: axios.create() }));
import { api } from '../lib/api';
import { programService } from './programService';

const originalAdapter = api.defaults.adapter;
afterEach(() => { api.defaults.adapter = originalAdapter; });

it.each([0, 3])('sends the viewed revision %s in the JSON body for edits and deletes', async version => {
  const requests: { method?: string; body: unknown }[] = [];
  api.defaults.adapter = async config => {
    expect(config.headers.getContentType()).toContain('application/json');
    expect(config.headers.get('If-Match')).toBe(`"${version}"`);
    requests.push({ method: config.method, body: JSON.parse(config.data) });
    return { data: {}, status: 200, statusText: 'OK', headers: {}, config };
  };
  await programService.update('program-id', { title: 'Updated', expectedVersion: version });
  await programService.remove('program-id', version);
  expect(requests).toEqual([
    { method: 'put', body: { title: 'Updated', expectedVersion: version } },
    { method: 'delete', body: { expectedVersion: version } },
  ]);
});
