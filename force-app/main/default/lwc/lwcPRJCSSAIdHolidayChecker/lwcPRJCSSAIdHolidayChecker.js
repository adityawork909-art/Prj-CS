import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import checkIdNumber from '@salesforce/apex/clsPRJCSSAIdHolidayController.checkIdNumber';

const SAMPLE_ID = '8001015009087';
const ID_LENGTH = 13;

/**
 * SA ID Holiday Checker - single component, four guided steps (User Stories 1-4).
 * Validates the SA ID client-side (Luhn/date/citizenship) so the search button stays
 * disabled until valid, then calls Apex to decode, persist (US3) and fetch holidays (US4).
 */
export default class LwcPRJCSSAIdHolidayChecker extends LightningElement {
    idNumber = '';
    isLoading = false;
    activeTab = 'tab1';

    // Client-side validation state (User Story 2)
    inlineError = '';
    isValidClient = false;
    touched = false;

    // Server result
    hasResult = false;
    result;
    holidays = [];
    dobDisplay = '';
    lastSearchedDisplay;

    // Sample IDs - quick-fill testing aid (all verified valid)
    showSamples = false;
    sampleIds = [
        { id: '8001015009087', dob: '1980-01-01', gender: 'Male', citizenship: 'SA Citizen' },
        { id: '9505150500188', dob: '1995-05-15', gender: 'Female', citizenship: 'Permanent Resident' },
        { id: '9006155500083', dob: '1990-06-15', gender: 'Male', citizenship: 'SA Citizen' },
        { id: '0012254500080', dob: '2000-12-25', gender: 'Female', citizenship: 'SA Citizen' },
        { id: '7503081500080', dob: '1975-03-08', gender: 'Female', citizenship: 'SA Citizen' },
        { id: '8811306000086', dob: '1988-11-30', gender: 'Male', citizenship: 'SA Citizen' },
        { id: '0207045000180', dob: '2002-07-04', gender: 'Male', citizenship: 'Permanent Resident' },
        { id: '9902284999081', dob: '1999-02-28', gender: 'Female', citizenship: 'SA Citizen' }
    ];

    // ---------- Step / tab model ----------
    get tabItems() {
        const make = (id, num, label) => {
            const isActive = this.activeTab === id;
            const isLocked = id !== 'tab1' && !this.hasResult;
            let cls = 'prjcs-step';
            if (isActive) {
                cls += ' prjcs-step_active';
            }
            if (isLocked) {
                cls += ' prjcs-step_locked';
            }
            return { id, num, label, active: isActive, disabled: isLocked, cls };
        };
        return [
            make('tab1', '1', 'Search'),
            make('tab2', '2', 'Validation'),
            make('tab3', '3', 'Saved Record'),
            make('tab4', '4', 'Holidays')
        ];
    }
    get isTab1() {
        return this.activeTab === 'tab1';
    }
    get isTab2() {
        return this.activeTab === 'tab2';
    }
    get isTab3() {
        return this.activeTab === 'tab3';
    }
    get isTab4() {
        return this.activeTab === 'tab4';
    }

    // ---------- Getters ----------
    get isSearchDisabled() {
        return !this.isValidClient || this.isLoading;
    }
    get showInlineError() {
        return this.touched && !this.isValidClient && !!this.inlineError;
    }
    get showValidHint() {
        return this.isValidClient;
    }
    get citizenshipLabel() {
        if (!this.result) {
            return '';
        }
        return this.result.isSaCitizen ? 'SA Citizen' : 'Permanent Resident';
    }
    get holidayWarning() {
        return this.result ? this.result.holidayWarning : null;
    }
    get hasHolidays() {
        return this.holidays && this.holidays.length > 0;
    }
    get holidayCountLabel() {
        const count = this.holidays ? this.holidays.length : 0;
        return count + (count === 1 ? ' holiday' : ' holidays');
    }

    // ---------- Handlers ----------
    handleTabClick(event) {
        const id = event.currentTarget.dataset.id;
        if (id === 'tab1' || this.hasResult) {
            this.activeTab = id;
        }
    }

    handleIdChange(event) {
        const target = event.target || {};
        const raw =
            typeof target.value === 'string'
                ? target.value
                : (event.detail && event.detail.value) || '';
        this.idNumber = raw.replace(/\D/g, '').slice(0, ID_LENGTH);
        this.touched = true;
        this.validateClient();
    }

    handleKeyUp(event) {
        if (event.key === 'Enter' && !this.isSearchDisabled) {
            this.handleSearch();
        }
    }

    handleUseSample() {
        this.idNumber = SAMPLE_ID;
        this.touched = true;
        this.validateClient();
    }

    toggleSamples() {
        this.showSamples = !this.showSamples;
    }

    handlePickSample(event) {
        this.idNumber = event.currentTarget.dataset.id;
        this.touched = true;
        this.validateClient();
        this.showSamples = false;
    }

    handleClear() {
        this.idNumber = '';
        this.inlineError = '';
        this.isValidClient = false;
        this.touched = false;
        this.hasResult = false;
        this.result = undefined;
        this.holidays = [];
        this.dobDisplay = '';
        this.lastSearchedDisplay = undefined;
        this.showSamples = false;
        this.activeTab = 'tab1';
    }

    async handleSearch() {
        this.validateClient();
        if (!this.isValidClient) {
            this.touched = true;
            return;
        }
        this.isLoading = true;
        try {
            const res = await checkIdNumber({ idNumber: this.idNumber });
            if (!res.isValid) {
                this.isValidClient = false;
                this.inlineError = res.errorMessage;
                this.touched = true;
                this.showToast('Invalid ID number', res.errorMessage, 'error');
                return;
            }
            this.result = res;
            this.dobDisplay = this.formatIsoDate(res.dateOfBirth, {
                year: 'numeric',
                month: 'long',
                day: '2-digit'
            });
            this.lastSearchedDisplay = new Date().toISOString();
            this.holidays = (res.holidays || []).map((holiday, index) => {
                const parts = this.holidayParts(holiday.holidayDate);
                return {
                    id: index + '-' + (holiday.holidayDate || holiday.name),
                    name: holiday.name,
                    holidayType: holiday.holidayType || 'Holiday',
                    mon: parts.mon,
                    day: parts.day,
                    fullDate: parts.full
                };
            });
            this.hasResult = true;
            this.activeTab = 'tab2';
            this.showToast(
                'Search complete',
                'ID validated. This ID has been searched ' + res.searchCount + ' time(s).',
                'success'
            );
            if (res.holidayWarning) {
                this.showToast('Holidays unavailable', res.holidayWarning, 'warning', 'sticky');
            }
        } catch (error) {
            const message =
                error && error.body && error.body.message
                    ? error.body.message
                    : 'An unexpected error occurred. Please try again.';
            this.showToast('Something went wrong', message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ---------- Client-side validation (mirror of Apex - User Story 2) ----------
    validateClient() {
        const id = this.idNumber;
        if (!id) {
            this.inlineError = 'Please enter your 13-digit ID number.';
            this.isValidClient = false;
            return;
        }
        if (id.length !== ID_LENGTH) {
            this.inlineError = 'Enter all 13 digits (' + id.length + '/13).';
            this.isValidClient = false;
            return;
        }
        if (!this.isValidDateOfBirth(id)) {
            this.inlineError = 'The first 6 digits are not a valid date of birth.';
            this.isValidClient = false;
            return;
        }
        const citizen = parseInt(id.charAt(10), 10);
        if (citizen !== 0 && citizen !== 1) {
            this.inlineError = 'The 11th digit (citizenship) must be 0 or 1.';
            this.isValidClient = false;
            return;
        }
        if (!this.isLuhnValid(id)) {
            this.inlineError = 'Checksum failed - please re-check the number.';
            this.isValidClient = false;
            return;
        }
        this.inlineError = '';
        this.isValidClient = true;
    }

    isValidDateOfBirth(id) {
        const yy = parseInt(id.substring(0, 2), 10);
        const mm = parseInt(id.substring(2, 4), 10);
        const dd = parseInt(id.substring(4, 6), 10);
        if (Number.isNaN(yy) || Number.isNaN(mm) || Number.isNaN(dd)) {
            return false;
        }
        if (mm < 1 || mm > 12 || dd < 1) {
            return false;
        }
        const now = new Date();
        const currentYy = now.getFullYear() % 100;
        const century = yy <= currentYy ? 2000 : 1900;
        const fullYear = century + yy;
        const daysInMonth = new Date(fullYear, mm, 0).getDate();
        if (dd > daysInMonth) {
            return false;
        }
        const candidate = new Date(fullYear, mm - 1, dd);
        return candidate <= now;
    }

    isLuhnValid(id) {
        let sum = 0;
        let alternate = false;
        for (let i = id.length - 1; i >= 0; i--) {
            let digit = parseInt(id.charAt(i), 10);
            if (alternate) {
                digit *= 2;
                if (digit > 9) {
                    digit -= 9;
                }
            }
            sum += digit;
            alternate = !alternate;
        }
        return sum % 10 === 0;
    }

    formatIsoDate(iso, options) {
        if (!iso) {
            return '';
        }
        const parts = String(iso).substring(0, 10).split('-');
        if (parts.length === 3) {
            const parsed = new Date(
                parseInt(parts[0], 10),
                parseInt(parts[1], 10) - 1,
                parseInt(parts[2], 10)
            );
            if (!Number.isNaN(parsed.getTime())) {
                return parsed.toLocaleDateString(undefined, options);
            }
        }
        return iso;
    }

    holidayParts(iso) {
        const parts = String(iso || '').substring(0, 10).split('-');
        if (parts.length !== 3) {
            return { mon: '', day: '', full: iso || '' };
        }
        const parsed = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10));
        if (Number.isNaN(parsed.getTime())) {
            return { mon: '', day: parts[2], full: iso };
        }
        return {
            mon: parsed.toLocaleString(undefined, { month: 'short' }).toUpperCase(),
            day: parts[2],
            full: parsed.toLocaleDateString(undefined, {
                weekday: 'short',
                day: '2-digit',
                month: 'long',
                year: 'numeric'
            })
        };
    }

    showToast(title, message, variant, mode) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant,
                mode: mode || 'dismissable'
            })
        );
    }
}
