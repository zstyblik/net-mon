CREATE TABLE net_mon (id_mon BIGSERIAL NOT NULL, 
	dn VARCHAR NOT NULL, 
	log_time TIMESTAMP NOT NULL, 
	state BIT NOT NULL
);
CREATE INDEX net_mon_index ON net_mon (dn, log_time);
