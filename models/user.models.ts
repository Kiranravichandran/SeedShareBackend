import { Table, Model, Column, DataType, PrimaryKey, AutoIncrement, } from 'sequelize-typescript';

@Table({ tableName: 'User', timestamps: false })
export class UserConfigurations extends Model<UserConfigurations> {
    @PrimaryKey
    @AutoIncrement
    @Column(DataType.STRING)
    id: number;

    @Column(DataType.STRING)
    fullName: string;

    @Column(DataType.STRING)
    phoneNumber: string;

    @Column(DataType.STRING)
    location: string;
}
