' use strict';

// Gets fabric contract api libraries and references within the code.

const { Contract } = require('fabric-contract-api');

class AdminContract extends Contract {
    constructor() {
        super('AdminContract');
    }

    async instantiate(ctx) {
        /*
        Instantiate function is created to test whether chaincode successfully deployed or not.
        */
        console.log('chaincode successfully deployed');
    }

    async approveNewUser(ctx, name, ssn) {
        /*
        approveNewUser is a method which is used to approve the farmer who is on the request asset.
        It supports following arguments:
        name --> farmer name
        ssn --> social security number of the farmer.
        */
        const userRequestKey = ctx.stub.createCompositeKey('SeedshareNetwork.farmer.request', [name, ssn])
        const userKey = ctx.stub.createCompositeKey('SeedshareNetwork.farmer', [name, ssn])
        const requestBuffer = await ctx.stub.getState(userRequestKey);
        console.log(requestBuffer.toString());
        if (requestBuffer) {
            let userdict = JSON.parse(requestBuffer.toString());
            userdict.upgradCoins = 0;
            const userBuffer = Buffer.from(JSON.stringify(userdict));
            await ctx.stub.putState(userKey, userBuffer);
            return userdict;
        }
        else {
            return 'Asset with key ' + name + ' does not exist on the network';
        }

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
        if (requestPropBuffer) {
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
        if (propBuffer) {
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
        if (propBuffer) {
            let propdict = JSON.parse(propBuffer.toString());
            // Check whether owner is updating the property.  No farmer other than owner is allowed to update the property.
            if (name == propdict.owner) {
                propdict.status = status;
                const propBuffer = Buffer.from(JSON.stringify(propdict));
                await ctx.stub.putState(propKey, propBuffer);
                return propdict;
            }

        }
        else {
            return "asset with property" + prop_id + "is not available on the network";
        }
    }

}
// module.exports is mandatory since we are exporting into index.js
module.exports = AdminContract;