import { Table, Model, Column, DataType, PrimaryKey, AutoIncrement, } from 'sequelize-typescript';

@Table({ tableName: 'Item', timestamps: false })
export class ItemConfiguration extends Model<ItemConfiguration> {
    @PrimaryKey
    @AutoIncrement
    @Column(DataType.STRING)
    id: number;

    @Column(DataType.STRING)
    itemName: string;

    @Column(DataType.STRING)
    amountItem: string;

    @Column(DataType.STRING)
    region: string;

    @Column(DataType.STRING)
    imageUrl: string;

    @Column(DataType.STRING)
    userId: number;

    @Column(DataType.STRING)
    carbonEmission: string;

    @Column(DataType.STRING)
    byProducts: string;
}
