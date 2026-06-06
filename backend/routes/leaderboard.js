const db = require('../db');
const { antsToAnet } = require('../services/miningEngine');

module.exports = async function (fastify) {

  /// 🏆 TOP USERS
  fastify.get('/top', async () => {
    const result = await db.query(`
      SELECT
        id,
        email,
        balance,
        GREATEST(COALESCE(ants_balance, 0)::numeric, COALESCE(ant_balance, 0)) AS ant_balance,
        successful_sessions
      FROM users
      ORDER BY GREATEST(COALESCE(ants_balance, 0)::numeric, COALESCE(ant_balance, 0)) DESC, id ASC
      LIMIT 20
    `);

    return result.rows.map((row) => ({
      ...row,
      ant_balance: Number(row.ant_balance || 0),
      balance: antsToAnet(row.ant_balance || 0),
    }));
  });

  /// 👤 USER RANK
  fastify.get('/rank/:userId', async (req) => {
    const { userId } = req.params;
    const id = parseInt(userId, 10);
    if (!id || isNaN(id)) return { error: 'Invalid userId' };

    const result = await db.query(`
      SELECT
        u.id,
        u.balance,
        GREATEST(COALESCE(u.ants_balance, 0)::numeric, COALESCE(u.ant_balance, 0)) AS ant_balance,
        (
          SELECT COUNT(*)::int + 1
          FROM users u2
          WHERE GREATEST(COALESCE(u2.ants_balance, 0)::numeric, COALESCE(u2.ant_balance, 0)) > GREATEST(COALESCE(u.ants_balance, 0)::numeric, COALESCE(u.ant_balance, 0))
             OR (
               GREATEST(COALESCE(u2.ants_balance, 0)::numeric, COALESCE(u2.ant_balance, 0)) = GREATEST(COALESCE(u.ants_balance, 0)::numeric, COALESCE(u.ant_balance, 0))
               AND u2.id < u.id
             )
        ) AS rank
      FROM users u
      WHERE u.id = $1
    `, [id]);

    if (!result.rows[0]) {
      return { error: 'User not found' };
    }

    return {
      ...result.rows[0],
      ant_balance: Number(result.rows[0].ant_balance || 0),
      balance: antsToAnet(result.rows[0].ant_balance || 0),
    };
  });

};