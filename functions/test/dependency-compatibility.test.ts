import {createServer} from 'node:http';
import {createRequire} from 'node:module';
import {describe, expect, it} from 'vitest';

const require = createRequire(import.meta.url);
// Resolve the actual Storage SDK dependency, not another installed gaxios major.
const storageRequire = createRequire(require.resolve('@google-cloud/storage'));
const {Gaxios} = storageRequire('gaxios');
const gaxiosRequire = createRequire(storageRequire.resolve('gaxios'));
const uuid = gaxiosRequire('uuid');

describe('Storage transport security override', () => {
  it('retains CommonJS UUID support and rejects undersized output buffers', () => {
    expect(uuid.validate(uuid.v4())).toBe(true);
    expect(() => uuid.v5('qa', uuid.v5.DNS, new Uint8Array(8))).toThrow(RangeError);
  });

  it('sends multipart metadata and content with a valid UUID boundary', async () => {
    let contentType = '', body = '';
    const server = createServer(async (req, res) => {
      contentType = String(req.headers['content-type']);
      for await (const chunk of req) body += chunk.toString();
      res.setHeader('Content-Type', 'application/json');
      res.end(JSON.stringify({accepted: true}));
    });
    await new Promise<void>(resolve => server.listen(0, '127.0.0.1', resolve));
    try {
      const address = server.address() as {port: number};
      const result = await new Gaxios().request({
        url: `http://127.0.0.1:${address.port}/upload`, method: 'POST',
        multipart: [
          {headers: {'Content-Type': 'application/json'}, content: '{"name":"qa.txt"}'},
          {headers: {'Content-Type': 'text/plain'}, content: 'DTS upload compatibility'},
        ],
      });
      const boundary = contentType.split('boundary=')[1];
      expect(uuid.validate(boundary)).toBe(true);
      expect(body).toContain(`--${boundary}`);
      expect(body).toContain('{"name":"qa.txt"}');
      expect(body).toContain('DTS upload compatibility');
      expect(result.data).toEqual({accepted: true});
    } finally {
      await new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
    }
  });
});
