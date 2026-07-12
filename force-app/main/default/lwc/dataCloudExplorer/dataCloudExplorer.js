import { LightningElement, track, wire } from 'lwc';
import fetchDashboardData from '@salesforce/apex/IdentityResolutionEngine.fetchDashboardData';
import runHarmonizationAura from '@salesforce/apex/IdentityResolutionEngine.runHarmonizationAura';
import { refreshApex } from '@salesforce/apex';

export default class DataCloudExplorer extends LightningElement {
    @track subscribers = [];
    @track posRecords = [];
    @track unifiedRecords = [];
    @track isProcessing = false;

    wiredDataResult;

    @wire(fetchDashboardData)
    wiredData(result) {
        this.wiredDataResult = result;
        if (result.data) {
            this.subscribers = result.data.subscribers || [];
            this.posRecords = result.data.pos || [];
            this.unifiedRecords = result.data.unified || [];
        } else if (result.error) {
            console.error('Error fetching data', result.error);
        }
    }

    get hasUnifiedData() {
        return this.unifiedRecords && this.unifiedRecords.length > 0;
    }

    handleRunHarmonization() {
        this.isProcessing = true;
        
        runHarmonizationAura()
            .then(() => {
                // Refresh the data to show the new stitched records
                return refreshApex(this.wiredDataResult);
            })
            .catch(error => {
                console.error('Harmonization failed', error);
            })
            .finally(() => {
                // Keep the spinner going slightly longer for dramatic demo effect
                setTimeout(() => {
                    this.isProcessing = false;
                }, 1200);
            });
    }
}
