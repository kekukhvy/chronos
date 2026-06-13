CREATE TABLE destinations (
                              id          VARCHAR(64)  NOT NULL,
                              type        VARCHAR(32)  NOT NULL,
                              config      JSONB        NOT NULL,
                              tenant_id   VARCHAR(64)  NOT NULL,
                              created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

                              CONSTRAINT pk_destinations PRIMARY KEY (id)
);

CREATE TABLE schedules (
                           id                  UUID         NOT NULL DEFAULT gen_random_uuid(),
                           name                VARCHAR(255) NOT NULL,
                           status              VARCHAR(32)  NOT NULL DEFAULT 'PENDING',
                           type                VARCHAR(32)  NOT NULL DEFAULT 'ONE_TIME',
                           run_at              TIMESTAMPTZ,
                           cron                VARCHAR(128),
                           timezone            VARCHAR(64),
                           destination_id      VARCHAR(64)  NOT NULL,
                           message_type        VARCHAR(255) NOT NULL,
                           payload             JSONB        NOT NULL,
                           tenant_id           VARCHAR(64)  NOT NULL,
                           retry_max_attempts  INT          NOT NULL DEFAULT 3,
                           retry_backoff       JSONB,
                           created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

                           CONSTRAINT pk_schedules      PRIMARY KEY (id),
                           CONSTRAINT fk_schedules_dest FOREIGN KEY (destination_id) REFERENCES destinations(id),
                           CONSTRAINT chk_schedule_type CHECK (
                               (type = 'ONE_TIME' AND run_at IS NOT NULL) OR
                               (type = 'CRON'     AND cron IS NOT NULL AND timezone IS NOT NULL)
                               )
);

CREATE INDEX idx_schedules_status_run_at ON schedules (status, run_at);
CREATE INDEX idx_schedules_tenant        ON schedules (tenant_id);

CREATE TABLE executions (
                            id            UUID         NOT NULL DEFAULT gen_random_uuid(),
                            schedule_id   UUID         NOT NULL,
                            status        VARCHAR(32)  NOT NULL,
                            attempt       INT          NOT NULL DEFAULT 1,
                            executed_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
                            next_retry_at TIMESTAMPTZ,
                            error         TEXT,

                            CONSTRAINT pk_executions       PRIMARY KEY (id),
                            CONSTRAINT fk_executions_sched FOREIGN KEY (schedule_id) REFERENCES schedules(id)
);

CREATE INDEX idx_executions_schedule_id ON executions (schedule_id);