' use strict';

// Gets fabric contract api libraries and references within the code.
const { Contract } = require('fabric-contract-api');

class FarmerContract extends Contract {
    constructor() {
        super('FarmerContract');
    }

    async instantiate(ctx) {
        /*
        Instantiate function is created to test whether chaincode successfully deployed or not.
        */
        console.log('chaincode successfully deployed');
    }

    async requestNewFarmer(ctx, name, emailId, phone_no, ssn) {
        /*
        requestNewFarmer method is for adding the new farmer as request asset within the network.
        It supports folowing arguments:
        name -> Name of the farmer
        emailId -> emailID of the farmer
        phone_no -> Phone number of the farmer
        ssn --> Social security number of the farmer
        */
        //create request asset for the farmer.
        const requestKey = ctx.stub.createCompositeKey('SeedshareNetwork.farmer.request', [name, ssn])
        const newRequestObject = {
            docType: 'farmer',
            name: name,
            emailId: emailId,
            phone_no: phone_no,
            createdAt: ctx.stub.getTxTimestamp()
        }
        const requestBuffer = Buffer.from(JSON.stringify(newRequestObject));
        // put the newRequestObject into request asset
        await ctx.stub.putState(requestKey, requestBuffer);
        return newRequestObject;
    }

    async viewUser(ctx, name, ssn) {
        /*
        viewUser method is to check the registered and validated users within the network
        It supports following arguments:
        name --> Name of the farmer
        ssn --> Social security number of the project
        */
        const userKey = ctx.stub.createCompositeKey('SeedshareNetwork.farmer', [name, ssn])
        const userBuffer = await ctx.stub.getState(userKey);
        if (userBuffer) {
            return JSON.parse(userBuffer.toString());
        }
        else {
            return 'Asset with key ' + name + ' does not exist on the network';
        }
    }

    async rechargeAccount(ctx, name, ssn, price, banktxnid) {
        /*
        rechargeAccount method is to recharge the farmer wallet something called upgradCoins within the network.
        It supports following arguments:
        name --> name of the farmer
        ssn --> social security number of the project
        price --> Amount needs to be added into farmer wallet.
        banktxnid --> a valid transaction ID for the addition of price into wallet.
        */
        const userKey = ctx.stub.createCompositeKey('SeedshareNetwork.farmer', [name, ssn])
        const userBuffer = await ctx.stub.getState(userKey);
        if (userBuffer) {
            if (banktxnid == 'upg100' || banktxnid == 'upg500' || banktxnid == 'upg1000') {
                let coins = banktxnid.replace('upg', '');
                let userdict = JSON.parse(userBuffer.toString());
                userdict.upgradCoins += parseInt(price);
                const rechargedaccBuffer = Buffer.from(JSON.stringify(userdict));
                await ctx.stub.putState(userKey, rechargedaccBuffer);
                return userdict;
            }
            else {
                return "Invalid bank transaction ID";
            }
        }
    }

    async propertyRegistrationRequest(ctx, prop_id, owner, price, status, name, ssn) {
        /*
       propertyRegistrationRequest method is for adding the new property as request asset within the network.
       It supports folowing arguments:
       prop_id --> ID of the property
       owner --> owner of the property
       price --> Price of the property
       status --> status to see whether its onSale or Registered
       name -> Name of the farmer
       ssn --> Social security number of the farmer
       */
        const propReqKey = ctx.stub.createCompositeKey('SeedshareNetwork.property.request', [prop_id, owner]);
        const userKey = ctx.stub.createCompositeKey('SeedshareNetwork.farmer', [name, ssn])
        const userBuffer = await ctx.stub.getState(userKey);
        if (userBuffer) {
            const newpropreqobject = {
                docType: 'property',
                prop_id: prop_id,
                owner: owner,
                price: price,
                status: status
            }
            const requestpropBuffer = Buffer.from(JSON.stringify(newpropreqobject));
            await ctx.stub.putState(propReqKey, requestpropBuffer);
            return newpropreqobject;
        }

    }
    async viewProperty(ctx, prop_id, owner) {
        /*
        viewProperty method is to check the registered and validated property within the network
        It supports following arguments:
        prop_id --> ID of the property
        owner --> owner of the property
        */
        const propKey = ctx.stub.createCompositeKey('SeedshareNetwork.property', [prop_id, owner]);
        const propBuffer = await ctx.stub.getState(propKey);
        if (propBuffer) {
            return JSON.parse(propBuffer.toString());
        }
        else {
            return 'Asset with key ' + prop_id + ' does not exist on the network';
        }
    }

    async purchaseProperty(ctx, prop_id, owner, buyers_name, buyers_ssn) {
        /*
        purchaseProperty is a method used for purchasing the property.  Both farmer and property should be validated and available in the network.
        prop_id --> ID of the property
        owner --> owner of the property
        buyers_name --> a buyer who is going to buy the property
        buyers_ssn --> a buyer social security number.
        */
        const propKey = ctx.stub.createCompositeKey('SeedshareNetwork.property', [prop_id, owner]);
        const propBuffer = await ctx.stub.getState(propKey);
        const userKey = ctx.stub.createCompositeKey('SeedshareNetwork.farmer', [buyers_name, buyers_ssn])
        const userBuffer = await ctx.stub.getState(userKey);
        //Checking whether property and farmer are registered on network
        if (propBuffer && userBuffer) {
            let propdict = JSON.parse(propBuffer.toString());
            let userdict = JSON.parse(userBuffer.toString());
            // Checking whether property status is on sale.
            if (propdict.status == "onSale") {
                // Check whether farmer have sufficient balance to buy the property.
                if (propdict.price <= userdict.upgradCoins) {
                    let deductprice = userdict.upgradCoins - propdict.price;
                    propdict.owner = buyers_name;
                    userdict.name = buyers_name;
                    //propdict.price = deductprice;
                    propdict.status = "registered";
                    userdict.upgradCoins = deductprice;
                    const updpropBuffer = Buffer.from(JSON.stringify(propdict));
                    const upduserBuffer = Buffer.from(JSON.stringify(userdict));
                    await ctx.stub.putState(propKey, updpropBuffer);
                    await ctx.stub.putState(userKey, upduserBuffer);
                    return propdict;
                }
                else {
                    return " Insufficient balance";
                }
            }
            else {
                return " property is not listed for sale";
            }
        }

    }


}
// module.exports is mandatory since we are exporting into index.js
module.exports = FarmerContract;