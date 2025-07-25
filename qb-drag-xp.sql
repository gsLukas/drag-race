CREATE TABLE IF NOT EXISTS `qb_drag_xp` (
    `citizenid` VARCHAR(50) COLLATE utf8mb4_general_ci NOT NULL,
    `xp` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`citizenid`),
    FOREIGN KEY (`citizenid`) REFERENCES players(`citizenid`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Para sincronizar XP:
-- Salvar XP: INSERT INTO qb_drag_xp (citizenid, xp) VALUES (?, ?) ON DUPLICATE KEY UPDATE xp = ?;
-- Carregar XP: SELECT xp FROM qb_drag_xp WHERE citizenid = ?;


CREATE TABLE IF NOT EXISTS `race_results` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50) COLLATE utf8mb4_general_ci NOT NULL,
    `player_name` VARCHAR(255) NOT NULL,
    `track` VARCHAR(50) NOT NULL,
    `time` DECIMAL(7,3) NOT NULL,
    `date` DATETIME NOT NULL,
    `burned` TINYINT(1) DEFAULT 0,
    `mode` VARCHAR(20) DEFAULT NULL,
    `xp` INT NOT NULL DEFAULT 0,
    `level` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_citizenid` (`citizenid`),
    KEY `idx_track` (`track`),
    KEY `idx_time` (`time`),
    FOREIGN KEY (`citizenid`) REFERENCES players(`citizenid`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Exemplos de queries otimizadas para leaderboard:

-- Top 3 geral (melhor tempo de cada jogador)
SELECT player_name, MIN(time) as best_time
FROM race_results
GROUP BY citizenid
ORDER BY best_time ASC
LIMIT 3;

-- Top 3 por modo (ex: apenas disputas)
SELECT player_name, MIN(time) as best_time
FROM race_results
WHERE mode = 'disputa'
GROUP BY citizenid
ORDER BY best_time ASC
LIMIT 3;

-- Estatísticas: total de queimadas por jogador
SELECT player_name, COUNT(*) as queimadas
FROM race_results
WHERE burned = 1
GROUP BY citizenid
ORDER BY queimadas DESC;

SELECT player_name, xp, level FROM race_results ORDER BY xp DESC, level DESC LIMIT 3;

SELECT player_name, MIN(time) as best_time
FROM race_results
WHERE burned = 0
GROUP BY citizenid
ORDER BY best_time ASC
LIMIT 3;

SELECT player_name, time, track, date
FROM race_results
WHERE burned = 0
ORDER BY date DESC, time ASC
LIMIT 10;