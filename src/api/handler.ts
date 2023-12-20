import { DbConfig } from "../../dao/db.config";
import { UserConfigurations } from "../../models/user.models";
import { v4 as uuidv4 } from 'uuid';
import { ItemConfiguration } from "../../models/item.models";
import { products } from "../../constants/co2-emission";
export class SeedShare {
    static async createUser(event) {
        return new Promise(async (resolve, reject) => {
            try {
                await DbConfig.connect();
                let urlParams = JSON.parse(event.body);
                const userData = {
                    id: uuidv4(),
                    fullName: urlParams.fullName,
                    phoneNumber: urlParams.phoneNumber,
                    location: urlParams.location,
                };
                await UserConfigurations.create(userData);
                const response = {
                    statusCode: 200,
                    body: JSON.stringify({ "Seedshare": "User Creation Successful" })
                };
                await DbConfig.closeConnection();
                resolve(response)
            } catch (error) {
                reject(error);
            }
        });
    }

    static async viewUser(event) {
        return new Promise(async (resolve, reject) => {
            try {
                await DbConfig.connect();
                let urlParams = JSON.parse(event.body);
                const viewUser = await UserConfigurations.findOne({
                    where: {
                        id: urlParams.id
                    }, raw: true
                });
                const response = {
                    statusCode: 200,
                    body: JSON.stringify(viewUser)
                };
                await DbConfig.closeConnection();
                resolve(response)
            } catch (error) {
                reject(error);
            }
        });
    }

    static async createItem(event) {
        return new Promise(async (resolve, reject) => {
            try {
                await DbConfig.connect();
                let urlParams: any = JSON.parse(event.body);
                const ItemData: any = {
                    id: uuidv4(),
                    itemName: urlParams.itemName,
                    amountItem: urlParams.amountItem,
                    region: urlParams.region,
                    imageUrl: urlParams.imageUrl,
                    userId: urlParams.userId,
                    carbonEmission: SeedShare.calculateCarbonEmissions(urlParams?.itemName, urlParams?.amountItem),
                    byProducts: SeedShare.getByProducts(urlParams?.itemName).toString()
                };
                await ItemConfiguration.create(ItemData);
                const response = {
                    statusCode: 200,
                    body: JSON.stringify({ "Seedshare": "Item added successfully" })
                };
                await DbConfig.closeConnection();
                resolve(response)
            } catch (error) {
                reject(error);
            }
        });
    }

    static async viewItems() {
        return new Promise(async (resolve, reject) => {
            try {
                await DbConfig.connect();
                const viewItems = await ItemConfiguration.findAll();
                const response = {
                    statusCode: 200,
                    body: JSON.stringify(viewItems)
                };
                await DbConfig.closeConnection();
                resolve(response)
            } catch (error) {
                reject(error);
            }
        });
    }

    static calculateCarbonEmissions(productName: string, weightInKg: number) {
        const calcEmission: any = products.find(p => p.product.toLowerCase() === productName.toLowerCase());
        return calcEmission.CO2Emissions ? calcEmission.CO2Emissions * weightInKg:  null;
    }

    static getByProducts(productName: string): string[] | null {
        const calcByproduct = products.find((p) => p.product.toLowerCase() === productName.toLowerCase());
        return calcByproduct ? calcByproduct.by_products : null;
      }
}

export const createUser = SeedShare.createUser;
export const viewUser = SeedShare.viewUser;
export const createItem = SeedShare.createItem;
export const viewItems = SeedShare.viewItems;


