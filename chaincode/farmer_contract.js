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
            ssn: ssn,
            createdAt: ctx.stub.getTxTimestamp()
        }
        const requestBuffer = Buffer.from(JSON.stringify(newRequestObject));
        // put the newRequestObject into request asset
        await ctx.stub.putState(requestKey, requestBuffer);
        
        return {
            message: 'Farmer request created successfully',
            requestKey: requestKey,
            farmer: newRequestObject
        };
    }

    async viewFarmer(ctx, name, ssn) {
        /*
        viewFarmer method is to check the registered and validated users within the network
        It supports following arguments:
        name --> Name of the farmer
        ssn --> Social security number of the project
        */
        const userKey = ctx.stub.createCompositeKey('SeedshareNetwork.farmer', [name, ssn])
        const userBuffer = await ctx.stub.getState(userKey);
        if (userBuffer && userBuffer.length > 0) {
            return JSON.parse(userBuffer.toString());
        }
        else {
            return 'Asset with key ' + name + ' does not exist on the network';
        }
    }

    async approveNewFarmer(ctx, name, ssn) {
        /*
        approveNewFarmer is a method which is used to approve the farmer who is on the request asset.
        It supports following arguments:
        name --> farmer name
        ssn --> social security number of the farmer.
        */
        const userRequestKey = ctx.stub.createCompositeKey('SeedshareNetwork.farmer.request', [name, ssn])
        const userKey = ctx.stub.createCompositeKey('SeedshareNetwork.farmer', [name, ssn])
        const requestBuffer = await ctx.stub.getState(userRequestKey);
        
        if (requestBuffer && requestBuffer.length > 0) {
            let userdict = JSON.parse(requestBuffer.toString());
            userdict.seedshareCoins = 0;
            const userBuffer = Buffer.from(JSON.stringify(userdict));
            await ctx.stub.putState(userKey, userBuffer);
            
            return {
                message: 'Farmer approved successfully',
                farmer: userdict
            };
        }
        else {
            return 'Request for farmer ' + name + ' with SSN ' + ssn + ' does not exist on the network';
        }
    }

    async rechargeAccount(ctx, name, ssn, price, banktxnid) {
        /*
        rechargeAccount method is to recharge the farmer wallet something called seedShareCoins within the network.
        It supports following arguments:
        name --> name of the farmer
        ssn --> social security number of the project
        price --> Amount needs to be added into farmer wallet.
        banktxnid --> a valid transaction ID for the addition of price into wallet.
        */
        const userKey = ctx.stub.createCompositeKey('SeedshareNetwork.farmer', [name, ssn])
        const userBuffer = await ctx.stub.getState(userKey);
        if (userBuffer && userBuffer.length > 0) {
            if (banktxnid == 'ssh100' || banktxnid == 'ssh500' || banktxnid == 'ssh1000') {
                let coins = banktxnid.replace('ssh', '');
                let userdict = JSON.parse(userBuffer.toString());
                userdict.seedshareCoins += parseInt(price);
                const rechargedaccBuffer = Buffer.from(JSON.stringify(userdict));
                await ctx.stub.putState(userKey, rechargedaccBuffer);
                return userdict;
            }
            else {
                return "Invalid bank transaction ID";
            }
        }
        else {
            return 'Farmer with key ' + name + ' does not exist on the network';
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
        if (userBuffer && userBuffer.length > 0) {
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
        else {
            return 'Farmer with key ' + name + ' does not exist on the network';
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
        
        //Checking whether property exists
        if (!propBuffer || propBuffer.length === 0) {
            return 'Property with ID ' + prop_id + ' and owner ' + owner + ' does not exist on the network';
        }
        
        //Checking whether farmer exists
        if (!userBuffer || userBuffer.length === 0) {
            return 'Farmer with name ' + buyers_name + ' does not exist on the network';
        }
        
        let propdict = JSON.parse(propBuffer.toString());
        let userdict = JSON.parse(userBuffer.toString());
        
        // Checking whether property status is on sale.
        if (propdict.status !== "onSale") {
            return 'Property is not listed for sale';
        }
        
        // Check whether farmer have sufficient balance to buy the property.
        if (propdict.price > userdict.seedshareCoins) {
            return 'Insufficient balance. Required: ' + propdict.price + ', Available: ' + userdict.seedshareCoins;
        }
        
        // Process the purchase
        let deductprice = userdict.seedshareCoins - propdict.price;
        
        // Create new property key with new owner
        const newPropKey = ctx.stub.createCompositeKey('SeedshareNetwork.property', [prop_id, buyers_name]);
        
        // Update property details
        propdict.owner = buyers_name;
        propdict.status = "registered";
        
        // Update user balance
        userdict.seedshareCoins = deductprice;
        
        const updpropBuffer = Buffer.from(JSON.stringify(propdict));
        const upduserBuffer = Buffer.from(JSON.stringify(userdict));
        
        // Update property with new owner (overwrite the old record)
        await ctx.stub.putState(newPropKey, updpropBuffer);
        await ctx.stub.putState(userKey, upduserBuffer);
        
        return {
            message: 'Property purchased successfully',
            property: propdict,
            buyer: {
                name: userdict.name,
                remainingBalance: userdict.seedshareCoins
            }
        };
    }

    async approvePropertyRegistration(ctx, prop_id, owner) {
        /*
        approvePropertyRegistration is a method which is used to approve the property who is on the request asset.
        It supports following arguments:
        prop_id --> ID of the property
        owner --> owner of the property.
        */
        const propRequestKey = ctx.stub.createCompositeKey('SeedshareNetwork.property.request', [prop_id, owner]);
        const propKey = ctx.stub.createCompositeKey('SeedshareNetwork.property', [prop_id, owner]);
        const requestPropBuffer = await ctx.stub.getState(propRequestKey);
        if (requestPropBuffer && requestPropBuffer.length > 0) {
            let propdict = JSON.parse(requestPropBuffer.toString());
            const propBuffer = Buffer.from(JSON.stringify(propdict));
            await ctx.stub.putState(propKey, propBuffer);
            return propdict;
        }
        else {
            return 'Asset with key property ' + prop_id + ' does not exist on the network';
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
        if (propBuffer && propBuffer.length > 0) {
            return JSON.parse(propBuffer.toString());
        }
        else {
            return 'Asset with key ' + prop_id + ' does not exist on the network';
        }
    }

    async updateProperty(ctx, prop_id, name, ssn, status) {
        /*
        updateProperty method is to update the property status from OnSale to Registered or viceVersa.
        It supports following arguments:
        prop_id --> ID of the property
        name --> name of the farmer
        ssn --> Social security number of farmer
        status --> property status
        */
        const propKey = ctx.stub.createCompositeKey('SeedshareNetwork.property', [prop_id, name]);
        const propBuffer = await ctx.stub.getState(propKey);
        if (propBuffer && propBuffer.length > 0) {
            let propdict = JSON.parse(propBuffer.toString());
            // Check whether owner is updating the property.  No farmer other than owner is allowed to update the property.
            if (name == propdict.owner) {
                propdict.status = status;
                const updatedPropBuffer = Buffer.from(JSON.stringify(propdict));
                await ctx.stub.putState(propKey, updatedPropBuffer);
                return propdict;
            }
            else {
                return "Only the property owner can update the property status";
            }
        }
        else {
            return "Asset with property " + prop_id + " is not available on the network";
        }
    }


}
// module.exports is mandatory since we are exporting into index.js
module.exports = FarmerContract;
