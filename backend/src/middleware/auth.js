const API_KEY = process.env.BACKEND_API_KEY;

function apiKeyAuth(req, res, next) {
  const apiKey = req.headers['x-api-key'];

  if (!API_KEY) {
    return res.status(500).json({ error: 'Server misconfigured: BACKEND_API_KEY not set' });
  }

  if (!apiKey || apiKey !== API_KEY) {
    return res.status(401).json({ error: 'Unauthorized: invalid or missing API key' });
  }

  next();
}

module.exports = { apiKeyAuth };
