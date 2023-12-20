' use strict';

// Gets fabric contract api libraries and references within the code.
const { Contract } = require('fabric-contract-api');

class UserContract extends Contract {
    constructor() {
        super('UserContract');
    }

    async instantiate(ctx) {
        /*
        Instantiate function is created to test whether chaincode successfully deployed or not.
        */
        console.log('chaincode successfully deployed');
    }

    async requestNewUser(ctx, name, phone_no, ssn) {
        /*
        requestNewUser method is for adding the new user as request asset within the network.
        It supports folowing arguments:
        name -> Name of the user
        phone_no -> Phone number of the user
        */
        //create request asset for the user.
        const newRequestObject = {
            docType: 'user',
            name: name,
            phone_no: phone_no,
            createdAt: ctx.stub.getTxTimestamp()
        }
         const requestBuffer = Buffer.from(JSON.stringify(newRequestObject));
        // put the newRequestObject into request asset
        const userKey = ctx.stub.createCompositeKey('SeedshareNetwork.user', [name, ssn])
        await ctx.stub.putState(userKey, requestBuffer);
        return newRequestObject;
    }

    async viewUser(ctx, name, ssn) {
        /*
        viewUser method is to check the registered and validated users within the network
        It supports following arguments:
        name --> Name of the user
        ssn --> Social security number of the project
        */
        const userKey = ctx.stub.createCompositeKey('SeedshareNetwork.user', [name, ssn])
        const userBuffer = await ctx.stub.getState(userKey);
        if (userBuffer) {
            return JSON.parse(userBuffer.toString());
        }
        else {
            return 'Asset with key ' + name + ' does not exist on the network';
        }
    }

    async rechargeAccount(ctx,name,ssn,price,banktxnid){
        /*
        rechargeAccount method is to recharge the user wallet something called seedshareCoins within the network.
        It supports following arguments:
        name --> name of the user
        ssn --> social security number of the project
        price --> Amount needs to be added into user wallet.
        banktxnid --> a valid transaction ID for the addition of price into wallet.
        */
        const userKey = ctx.stub.createCompositeKey('SeedshareNetwork.user', [name,ssn])
        const userBuffer = await ctx.stub.getState(userKey);
        if(userBuffer){
            if(banktxnid=='ssh100' || banktxnid=='ssh500' || banktxnid=='ssh1000')
            {
                let coins = banktxnid.replace('ssh','');
                let userdict = JSON.parse(userBuffer.toString());
                userdict.seedshareCoins+= parseInt(price);
                const rechargedaccBuffer = Buffer.from(JSON.stringify(userdict));
                await ctx.stub.putState(userKey, rechargedaccBuffer);
                return userdict;
            }
            else{
                return "Invalid bank transaction ID";
            }
        }
    }


}
// module.exports is mandatory since we are exporting into index.js
module.exports = UserContract;