import { Sequelize } from 'sequelize-typescript';
import { decamelize } from 'humps';
import { UserConfigurations } from '../models/user.models';
import pg from 'pg';
import { ItemConfiguration } from '../models/item.models';
export class DbConfig {
    static sequelize: Sequelize = null;
    static readerConnection: Sequelize = null;

    public static async connect() {
        this.sequelize = new Sequelize({
            database: 'seedshare',
            username: 'postgres',
            dialect: 'postgres',
            password: '123456789sih',
            port: '5432',
            host: 'database-1.cg4pewlhhviw.us-east-1.rds.amazonaws.com',
            benchmark: true,
            dialectModule: pg,
            dialectOptions: {
                connectTimeout: 60000
            },
            pool: {
                max: 20,
                min: 0,
                acquire: 60000,
                idle: 10000
            }
        });
        this.init();
        this.sequelize.authenticate().then(function (error) {

        })
            .catch(function (error) {

            });
    }

    public static init() {
        this.sequelize.addHook('beforeDefine', attributes => {
            Object.keys(attributes).forEach(key => {
                if (typeof attributes[key] !== 'function') {
                    attributes[key]['field'] = decamelize(key);
                }
            });
        });
        this.registerModels();
    }
    public static registerModels() {
        this.sequelize.addModels([UserConfigurations, ItemConfiguration]);
    }

    public static async closeConnection() {
        return this.sequelize ? this.sequelize.close() : null;
    }
}