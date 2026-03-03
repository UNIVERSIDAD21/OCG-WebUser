import express from 'express';
import cors from 'cors';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const DB_PATH = path.join(__dirname, 'data', 'users.json');

const app = express();
app.use(cors());
app.use(express.json());

const readUsers = async () => {
  const raw = await fs.readFile(DB_PATH, 'utf-8');
  return JSON.parse(raw);
};

const writeUsers = async (users) => {
  await fs.writeFile(DB_PATH, JSON.stringify(users, null, 2));
};

const sanitize = (u) => ({
  uid: u.uid,
  email: u.email,
  displayName: u.displayName,
  role: u.role,
  status: u.status,
  createdAt: u.createdAt,
});

app.get('/api/health', (_req, res) => {
  res.json({ ok: true });
});

app.post('/api/auth/register', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) return res.status(400).json({ message: 'Email y contraseña requeridos.' });

    const users = await readUsers();
    const exists = users.some((u) => u.email.toLowerCase() === String(email).toLowerCase());
    if (exists) return res.status(409).json({ message: 'El correo ya está registrado.' });

    const user = {
      uid: crypto.randomUUID(),
      email,
      password,
      displayName: '',
      role: 'patient',
      status: 'active',
      createdAt: new Date().toISOString(),
    };

    users.push(user);
    await writeUsers(users);

    return res.status(201).json({ user: sanitize(user) });
  } catch {
    return res.status(500).json({ message: 'Error creando cuenta.' });
  }
});

app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    const users = await readUsers();
    const found = users.find((u) => u.email.toLowerCase() === String(email).toLowerCase());
    if (!found || found.password !== password) {
      return res.status(401).json({ message: 'Credenciales inválidas.' });
    }
    return res.json({ user: sanitize(found) });
  } catch {
    return res.status(500).json({ message: 'Error en login.' });
  }
});

app.post('/api/auth/reset-password', async (req, res) => {
  try {
    const { email } = req.body;
    const users = await readUsers();
    const found = users.find((u) => u.email.toLowerCase() === String(email).toLowerCase());
    if (!found) return res.status(404).json({ message: 'Correo no encontrado.' });
    return res.json({ message: 'Correo de recuperación simulado enviado.' });
  } catch {
    return res.status(500).json({ message: 'Error en recuperación.' });
  }
});

const PORT = 8787;
const HOST = '127.0.0.1';
app.listen(PORT, HOST, () => {
  console.log(`OCG local auth API running on http://${HOST}:${PORT}`);
});
