// Input is a PUBLIC signing certificate exported as DER, never a private key.
const { readFileSync } = require('node:fs');
const { createHash, X509Certificate } = require('node:crypto');
const [certificatePath] = process.argv.slice(2);
if (!certificatePath) throw new Error('Usage: node tool/sms_app_hash.cjs public-signing-certificate.der');
const certificate = new X509Certificate(readFileSync(certificatePath));
const packageName = 'ug.go.kcca.weyonje.weyonje';
const digest = createHash('sha256').update(`${packageName} ${certificate.raw.toString('hex')}`, 'utf8').digest('base64');
console.log(digest.slice(0, 11));
